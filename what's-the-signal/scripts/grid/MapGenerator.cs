using Godot;
using System.Collections.Generic;

public partial class MapGenerator : Node
{
    [Signal]
    public delegate void MapGeneratedEventHandler ( Vector2I start, Vector2I end, int pathLength );

    [Export] public MapConfig Config { get; set; }

    private static readonly Vector2I[] Directions =
    {
        new Vector2I( 1, 0 ),
        new Vector2I( -1, 0 ),
        new Vector2I( 0, 1 ),
        new Vector2I( 0, -1 ),
    };

    public override void _Ready ()
    {
        EnsureConfig();
        GetNode<GameManager>( "/root/GameManager" )
            .ReportReady( "MapGenerator", $"pathLength={Config.MinPathLength}..{Config.MaxPathLength}, branch={Config.BranchChance}, turn={Config.TurnChance}" );
    }

    public void Generate ( Grid grid )
    {
        if ( grid == null || grid.Rng == null )
        {
            GD.PushWarning( "MapGenerator: grid/Rng not ready" );
            return;
        }
        EnsureConfig();

        var rng = grid.Rng;
        int targetLength = ChoosePathLength( rng );
        int minAcceptable = Mathf.Max( 1, Config.MinPathLength );
        int maxAttempts = Mathf.Max( 1, Config.MaxGenerationAttempts );

        GD.Print( $"MapGenerator: starting (seed={grid.GetSeed()}, targetLength={targetLength})" );

        var pathCells = TryCarveToMinimum( grid, rng, targetLength, maxAttempts, minAcceptable, out int attempts );

        if ( pathCells.Count < minAcceptable )
        {
            pathCells = TryFallbackSeeds( grid, targetLength, maxAttempts, minAcceptable );
            rng = grid.Rng;
        }

        int junctionsAdded = AddJunctions( grid, rng );
        FillTerrain( grid, rng );
        ComputeDistances( grid, pathCells );

        grid.Start = pathCells[ 0 ];
        grid.End = pathCells[ pathCells.Count - 1 ];
        grid.RefreshAll();

        int totalWalkable = pathCells.Count + junctionsAdded;
        GD.Print( $"MapGenerator: done — {pathCells.Count} path + {junctionsAdded} junctions = {totalWalkable} walkable, {grid.Start} -> {grid.End}" );
        EmitSignal( SignalName.MapGenerated, grid.Start, grid.End, totalWalkable );
    }

    private void EnsureConfig ()
    {
        if ( Config != null )
        {
            return;
        }
        GD.PushWarning( "MapGenerator: Config not set, using defaults" );
        Config = new MapConfig();
    }

    private int ChoosePathLength ( RandomNumberGenerator rng )
    {
        int min = Mathf.Max( 1, Config.MinPathLength );
        int max = Mathf.Max( min, Config.MaxPathLength );
        return rng.RandiRange( min, max );
    }

    private List<Vector2I> TryCarveToMinimum ( Grid grid, RandomNumberGenerator rng, int targetLength, int maxAttempts, int minAcceptable, out int attempts )
    {
        List<Vector2I> result = null;
        for ( attempts = 1; attempts <= maxAttempts; attempts++ )
        {
            ResetCells( grid );
            result = CarvePath( grid, rng, targetLength );
            if ( result.Count >= minAcceptable )
            {
                return result;
            }
            if ( attempts < maxAttempts )
            {
                GD.Print( $"MapGenerator: attempt #{attempts} produced {result.Count} cells (< {minAcceptable}), regenerating" );
            }
        }
        return result;
    }

    private List<Vector2I> TryFallbackSeeds ( Grid grid, int targetLength, int maxAttempts, int minAcceptable )
    {
        var fallbacks = Config.FallbackSeeds;
        if ( fallbacks == null || fallbacks.Length == 0 )
        {
            GD.PushWarning( $"MapGenerator: primary seed exhausted and no fallback seeds configured" );
            return CollectCurrentPath( grid );
        }

        GD.Print( $"MapGenerator: primary seed exhausted, trying {fallbacks.Length} fallback seed(s)" );
        List<Vector2I> result = null;
        for ( int i = 0; i < fallbacks.Length; i++ )
        {
            long fallback = fallbacks[ i ];
            GD.Print( $"MapGenerator: fallback #{i + 1}/{fallbacks.Length} — reloading grid with seed={fallback}" );
            grid.LoadSeed( fallback );
            int newTarget = ChoosePathLength( grid.Rng );
            result = TryCarveToMinimum( grid, grid.Rng, newTarget, maxAttempts, minAcceptable, out _ );
            if ( result.Count >= minAcceptable )
            {
                GD.Print( $"MapGenerator: accepted fallback #{i + 1} (seed={fallback}, {result.Count} cells)" );
                return result;
            }
        }

        GD.PushWarning( $"MapGenerator: all fallback seeds exhausted — using best path ({result?.Count ?? 0}/{minAcceptable} cells)" );
        return result ?? CollectCurrentPath( grid );
    }

    private static List<Vector2I> CollectCurrentPath ( Grid grid )
    {
        var list = new List<Vector2I>();
        for ( int x = 0; x < grid.Width; x++ )
        {
            for ( int y = 0; y < grid.Height; y++ )
            {
                var coords = new Vector2I( x, y );
                if ( grid.GetCell( coords ).IsWalkable )
                {
                    list.Add( coords );
                }
            }
        }
        return list;
    }

    private void ResetCells ( Grid grid )
    {
        for ( int x = 0; x < grid.Width; x++ )
        {
            for ( int y = 0; y < grid.Height; y++ )
            {
                var cell = grid.GetCell( new Vector2I( x, y ) );
                cell.IsWalkable = false;
                cell.IsExplored = false;
                cell.DistanceFromStart = -1;
                cell.Kind = CellKinds.Walkable;
            }
        }
    }

    private void FillTerrain ( Grid grid, RandomNumberGenerator rng )
    {
        for ( int x = 0; x < grid.Width; x++ )
        {
            for ( int y = 0; y < grid.Height; y++ )
            {
                var cell = grid.GetCell( new Vector2I( x, y ) );
                if ( !cell.IsWalkable )
                {
                    cell.Kind = PickTerrainKind( rng );
                }
            }
        }
    }

    private List<Vector2I> CarvePath ( Grid grid, RandomNumberGenerator rng, int targetLength )
    {
        var visited = new HashSet<Vector2I>();
        var path = new List<Vector2I>();

        var current = ResolveStart( grid );
        var direction = RandomDirection( rng );
        MarkWalkable( grid, current );
        visited.Add( current );
        path.Add( current );

        int rejected = 0;
        int backtracks = 0;
        int branches = 0;
        int safety = targetLength * 32;

        while ( path.Count < targetLength && safety-- > 0 )
        {
            if ( rng.Randf() < Config.TurnChance )
            {
                direction = RandomDirection( rng );
            }

            if ( !TryStep( grid, rng, current, ref direction, visited, out Vector2I next, ref rejected ) )
            {
                if ( !TryBacktrack( grid, path, visited, rng, out current, out direction, ref rejected ) )
                {
                    break;
                }
                backtracks++;
                continue;
            }

            current = next;
            MarkWalkable( grid, current );
            visited.Add( current );
            path.Add( current );

            if ( path.Count > 2 && rng.Randf() < Config.BranchChance )
            {
                current = path[ (int)( rng.Randi() % (uint)path.Count ) ];
                direction = RandomDirection( rng );
                branches++;
            }
        }

        if ( rejected > 0 || branches > 0 )
        {
            GD.Print( $"MapGenerator: {rejected} rejected, {branches} branches, {backtracks} backtracks" );
        }
        return path;
    }

    private bool TryStep ( Grid grid, RandomNumberGenerator rng, Vector2I from, ref Vector2I direction, HashSet<Vector2I> visited, out Vector2I next, ref int rejected )
    {
        next = from + direction;
        if ( CanPlaceWalkable( grid, next, visited, ref rejected ) )
        {
            return true;
        }
        foreach ( var alt in ShuffledDirections( rng ) )
        {
            if ( alt == direction )
            {
                continue;
            }
            var candidate = from + alt;
            if ( CanPlaceWalkable( grid, candidate, visited, ref rejected ) )
            {
                direction = alt;
                next = candidate;
                return true;
            }
        }
        return false;
    }

    private bool TryBacktrack ( Grid grid, List<Vector2I> path, HashSet<Vector2I> visited, RandomNumberGenerator rng, out Vector2I resumeAt, out Vector2I resumeDir, ref int rejected )
    {
        for ( int i = path.Count - 1; i >= 0; i-- )
        {
            var candidate = path[ i ];
            foreach ( var dir in ShuffledDirections( rng ) )
            {
                if ( CanPlaceWalkable( grid, candidate + dir, visited, ref rejected ) )
                {
                    resumeAt = candidate;
                    resumeDir = dir;
                    return true;
                }
            }
        }
        resumeAt = default;
        resumeDir = default;
        return false;
    }

    private int AddJunctions ( Grid grid, RandomNumberGenerator rng )
    {
        int target = rng.RandiRange( Mathf.Max( 0, Config.MinJunctions ), Mathf.Max( Config.MinJunctions, Config.MaxJunctions ) );
        if ( target <= 0 )
        {
            return 0;
        }

        var candidates = new List<Vector2I>();
        for ( int x = 0; x < grid.Width; x++ )
        {
            for ( int y = 0; y < grid.Height; y++ )
            {
                var coords = new Vector2I( x, y );
                if ( IsJunctionCandidate( grid, coords ) )
                {
                    candidates.Add( coords );
                }
            }
        }

        int created = 0;
        while ( created < target && candidates.Count > 0 )
        {
            int idx = rng.RandiRange( 0, candidates.Count - 1 );
            var pick = candidates[ idx ];
            candidates.RemoveAt( idx );
            if ( !IsJunctionCandidate( grid, pick ) )
            {
                continue;
            }
            MarkWalkable( grid, pick );
            created++;
        }

        if ( created < target )
        {
            GD.PushWarning( $"MapGenerator: only created {created}/{target} junctions" );
        }
        return created;
    }

    private bool IsJunctionCandidate ( Grid grid, Vector2I coords )
    {
        var cell = grid.GetCell( coords );
        if ( cell.IsWalkable )
        {
            return false;
        }

        int walkableNeighbors = CountWalkableNeighbors( grid, coords );
        if ( walkableNeighbors < 2 || walkableNeighbors > Config.MaxJunctionNeighbors )
        {
            return false;
        }
        if ( Config.ForbidDoubleWidth && WouldCreate2x2Block( grid, coords ) )
        {
            return false;
        }
        foreach ( var dir in Directions )
        {
            var n = coords + dir;
            if ( grid.InBounds( n ) && grid.GetCell( n ).IsWalkable
                 && CountWalkableNeighbors( grid, n ) + 1 > Config.MaxJunctionNeighbors )
            {
                return false;
            }
        }
        return true;
    }

    private bool CanPlaceWalkable ( Grid grid, Vector2I coords, HashSet<Vector2I> visited, ref int rejected )
    {
        if ( !grid.InBounds( coords ) || visited.Contains( coords ) )
        {
            return false;
        }
        if ( CountWalkableNeighbors( grid, coords ) > Config.MaxPathNeighbors )
        {
            rejected++;
            return false;
        }
        if ( Config.ForbidDoubleWidth && WouldCreate2x2Block( grid, coords ) )
        {
            rejected++;
            return false;
        }
        foreach ( var dir in Directions )
        {
            var n = coords + dir;
            if ( grid.InBounds( n ) && grid.GetCell( n ).IsWalkable
                 && CountWalkableNeighbors( grid, n ) + 1 > Config.MaxPathNeighbors )
            {
                rejected++;
                return false;
            }
        }
        return true;
    }

    private static int CountWalkableNeighbors ( Grid grid, Vector2I coords )
    {
        int count = 0;
        foreach ( var dir in Directions )
        {
            var n = coords + dir;
            if ( grid.InBounds( n ) && grid.GetCell( n ).IsWalkable )
            {
                count++;
            }
        }
        return count;
    }

    private static bool WouldCreate2x2Block ( Grid grid, Vector2I coords )
    {
        for ( int ox = -1; ox <= 0; ox++ )
        {
            for ( int oy = -1; oy <= 0; oy++ )
            {
                if ( Square2x2FullyWalkable( grid, coords, new Vector2I( coords.X + ox, coords.Y + oy ) ) )
                {
                    return true;
                }
            }
        }
        return false;
    }

    private static bool Square2x2FullyWalkable ( Grid grid, Vector2I promoted, Vector2I topLeft )
    {
        for ( int dx = 0; dx < 2; dx++ )
        {
            for ( int dy = 0; dy < 2; dy++ )
            {
                var c = new Vector2I( topLeft.X + dx, topLeft.Y + dy );
                if ( c == promoted )
                {
                    continue;
                }
                if ( !grid.InBounds( c ) || !grid.GetCell( c ).IsWalkable )
                {
                    return false;
                }
            }
        }
        return true;
    }

    private static void ComputeDistances ( Grid grid, List<Vector2I> pathCells )
    {
        if ( pathCells.Count == 0 )
        {
            return;
        }
        var queue = new Queue<Vector2I>();
        var start = pathCells[ 0 ];
        grid.GetCell( start ).DistanceFromStart = 0;
        queue.Enqueue( start );

        while ( queue.Count > 0 )
        {
            var here = queue.Dequeue();
            int hereDist = grid.GetCell( here ).DistanceFromStart;
            foreach ( var dir in Directions )
            {
                var n = here + dir;
                if ( !grid.InBounds( n ) )
                {
                    continue;
                }
                var cell = grid.GetCell( n );
                if ( !cell.IsWalkable || cell.DistanceFromStart >= 0 )
                {
                    continue;
                }
                cell.DistanceFromStart = hereDist + 1;
                queue.Enqueue( n );
            }
        }
    }

    private static void MarkWalkable ( Grid grid, Vector2I coords )
    {
        var cell = grid.GetCell( coords );
        cell.IsWalkable = true;
        cell.Kind = CellKinds.Walkable;
    }

    private Vector2I ResolveStart ( Grid grid )
    {
        if ( grid.InBounds( Config.StartCoords ) )
        {
            return Config.StartCoords;
        }
        return new Vector2I( 0, grid.Height / 2 );
    }

    private string PickTerrainKind ( RandomNumberGenerator rng )
    {
        var kinds = Config.TerrainKinds;
        if ( kinds == null || kinds.Length == 0 )
        {
            return CellKinds.Forest;
        }

        float total = 0f;
        for ( int i = 0; i < kinds.Length; i++ )
        {
            total += WeightAt( i );
        }
        if ( total <= 0f )
        {
            return kinds[ (int)( rng.Randi() % kinds.Length ) ];
        }

        float roll = rng.Randf() * total;
        float acc = 0f;
        for ( int i = 0; i < kinds.Length; i++ )
        {
            acc += WeightAt( i );
            if ( roll <= acc )
            {
                return kinds[ i ];
            }
        }
        return kinds[ kinds.Length - 1 ];
    }

    private float WeightAt ( int i )
    {
        var weights = Config.TerrainWeights;
        if ( weights == null || i >= weights.Length )
        {
            return 1f;
        }
        return Mathf.Max( 0f, weights[ i ] );
    }

    private static Vector2I RandomDirection ( RandomNumberGenerator rng )
    {
        return Directions[ (int)( rng.Randi() % 4 ) ];
    }

    private static Vector2I[] ShuffledDirections ( RandomNumberGenerator rng )
    {
        var copy = new Vector2I[ 4 ];
        Directions.CopyTo( copy, 0 );
        for ( int i = 3; i > 0; i-- )
        {
            int j = (int)( rng.Randi() % (uint)( i + 1 ) );
            ( copy[ i ], copy[ j ] ) = ( copy[ j ], copy[ i ] );
        }
        return copy;
    }
}
