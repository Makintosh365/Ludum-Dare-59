using Godot;
using System.Collections.Generic;

public partial class Grid : Node2D
{
    [Signal]
    public delegate void SeedChangedEventHandler ( long seed );

    [Export] public GridConfig Config { get; set; }

    public int Width { get; private set; }
    public int Height { get; private set; }
    public int CellSize { get; private set; }
    public long Seed { get; private set; }
    public RandomNumberGenerator Rng { get; private set; }

    public Vector2I Start { get; set; } = Vector2I.Zero;
    public Vector2I End { get; set; } = new Vector2I( -1, -1 );

    public override void _Ready ()
    {
        EnsureConfig();
        Build( Config.SeedInput );
        GetNode<GameManager>( "/root/GameManager" )
            .ReportReady( "Grid", $"{Width}x{Height}, cellSize={CellSize}, seed={Seed}" );
    }

    public override void _Draw ()
    {
        if ( !Config.DrawDebugOverlay || _cells == null )
        {
            return;
        }

        var outlineColor = new Color( 1, 1, 1, 0.25f );
        var wallColor = new Color( 1, 0.2f, 0.2f, 0.35f );
        var exploredColor = new Color( 1, 1, 0.4f, 0.15f );

        for ( int x = 0; x < Width; x++ )
        {
            for ( int y = 0; y < Height; y++ )
            {
                var rect = new Rect2( x * CellSize, y * CellSize, CellSize, CellSize );
                var cell = _cells[ x, y ];
                if ( !cell.IsWalkable )
                {
                    DrawRect( rect, wallColor, true );
                }
                if ( cell.IsExplored )
                {
                    DrawRect( rect, exploredColor, true );
                }
                DrawRect( rect, outlineColor, false );
            }
        }
    }

    public long GetSeed () => Seed;

    public void LoadSeed ( long seed )
    {
        TearDown();
        Build( seed );
        EmitSignal( SignalName.SeedChanged, Seed );
    }

    public GridCell GetCell ( Vector2I coords )
    {
        return InBounds( coords ) ? _cells[ coords.X, coords.Y ] : null;
    }

    public bool TryGetCell ( Vector2I coords, out GridCell cell )
    {
        if ( !InBounds( coords ) )
        {
            cell = null;
            return false;
        }
        cell = _cells[ coords.X, coords.Y ];
        return true;
    }

    public bool InBounds ( Vector2I coords )
    {
        return coords.X >= 0 && coords.X < Width && coords.Y >= 0 && coords.Y < Height;
    }

    public Vector2 CellToWorld ( Vector2I coords )
    {
        return new Vector2( coords.X * CellSize + CellSize / 2f, coords.Y * CellSize + CellSize / 2f );
    }

    public Vector2I WorldToCell ( Vector2 world )
    {
        return new Vector2I( Mathf.FloorToInt( world.X / CellSize ), Mathf.FloorToInt( world.Y / CellSize ) );
    }

    public bool IsWalkable ( Vector2I coords )
    {
        return InBounds( coords ) && _cells[ coords.X, coords.Y ].IsWalkable;
    }

    public bool AreAdjacent ( Vector2I a, Vector2I b )
    {
        var diff = a - b;
        return Mathf.Abs( diff.X ) + Mathf.Abs( diff.Y ) == 1;
    }

    public bool CanMove ( Vector2I from, Vector2I to )
    {
        return InBounds( from ) && InBounds( to ) && AreAdjacent( from, to ) && IsWalkable( to );
    }

    public void RefreshCellVisual ( Vector2I coords )
    {
        if ( !InBounds( coords ) )
        {
            return;
        }
        ApplyTexture( _sprites[ coords.X, coords.Y ], _cells[ coords.X, coords.Y ] );
        QueueRedraw();
    }

    public void RefreshAll ()
    {
        if ( _cells == null || _sprites == null )
        {
            return;
        }
        for ( int x = 0; x < Width; x++ )
        {
            for ( int y = 0; y < Height; y++ )
            {
                ApplyTexture( _sprites[ x, y ], _cells[ x, y ] );
            }
        }
        QueueRedraw();
    }

    private GridCell[,] _cells;
    private Sprite2D[,] _sprites;
    private readonly Dictionary<string, Texture2D> _textureCache = new();

    private void EnsureConfig ()
    {
        if ( Config != null )
        {
            return;
        }
        GD.PushWarning( "Grid: Config not set, using defaults" );
        Config = new GridConfig();
    }

    private void Build ( long requestedSeed )
    {
        EnsureConfig();
        Width = Config.Width;
        Height = Config.Height;
        CellSize = Config.CellSize;

        Seed = requestedSeed != 0 ? requestedSeed : PickRandomSeed();
        Rng = new RandomNumberGenerator { Seed = (ulong)Seed };

        GD.Print( $"Grid: building cells (seed={Seed})" );

        _cells = new GridCell[ Width, Height ];
        _sprites = new Sprite2D[ Width, Height ];

        for ( int x = 0; x < Width; x++ )
        {
            for ( int y = 0; y < Height; y++ )
            {
                var coords = new Vector2I( x, y );
                var cell = new GridCell( coords );
                _cells[ x, y ] = cell;

                var sprite = new Sprite2D
                {
                    Name = $"Cell_{x}_{y}",
                    Centered = true,
                    Position = CellToWorld( coords ),
                };
                ApplyTexture( sprite, cell );
                AddChild( sprite );
                _sprites[ x, y ] = sprite;
            }
        }

        QueueRedraw();
    }

    private void TearDown ()
    {
        if ( _sprites == null )
        {
            return;
        }
        for ( int x = 0; x < _sprites.GetLength( 0 ); x++ )
        {
            for ( int y = 0; y < _sprites.GetLength( 1 ); y++ )
            {
                if ( GodotObject.IsInstanceValid( _sprites[ x, y ] ) )
                {
                    _sprites[ x, y ].QueueFree();
                }
            }
        }
        _sprites = null;
        _cells = null;
    }

    private void ApplyTexture ( Sprite2D sprite, GridCell cell )
    {
        var texture = LoadTextureForKind( cell.Kind );
        sprite.Texture = texture;
        if ( texture != null && texture.GetWidth() > 0 && texture.GetHeight() > 0 )
        {
            sprite.Scale = new Vector2(
                (float)CellSize / texture.GetWidth(),
                (float)CellSize / texture.GetHeight()
            );
        }
        else
        {
            sprite.Scale = Vector2.One;
        }
    }

    private Texture2D LoadTextureForKind ( string kind )
    {
        if ( string.IsNullOrEmpty( kind ) )
        {
            return null;
        }
        if ( _textureCache.TryGetValue( kind, out var cached ) )
        {
            return cached;
        }
        var path = Config.TexturesRoot.TrimEnd( '/' ) + "/" + kind + ".png";
        if ( !ResourceLoader.Exists( path ) )
        {
            GD.PushWarning( $"Grid: texture not found at {path}" );
            _textureCache[ kind ] = null;
            return null;
        }
        var texture = ResourceLoader.Load<Texture2D>( path );
        _textureCache[ kind ] = texture;
        return texture;
    }

    private static long PickRandomSeed ()
    {
        var rng = new RandomNumberGenerator();
        rng.Randomize();
        long value = (long)rng.Seed;
        return value != 0 ? value : 1;
    }
}
