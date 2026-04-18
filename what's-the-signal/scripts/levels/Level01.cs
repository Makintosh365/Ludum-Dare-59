using Godot;

public partial class Level01 : Node2D
{
    private GameManager _gm;

    public override void _Ready ()
    {
        _gm = GetNode<GameManager>( "/root/GameManager" );
        GetNode<Button>( "%VictoryButton" ).Pressed += _gm.TriggerVictory;
        GetNode<Button>( "%DefeatButton" ).Pressed += _gm.TriggerDefeat;
        _gm.StateChanged += OnStateChanged;

        var grid = GetNode<Grid>( "Grid" );
        var generator = GetNode<MapGenerator>( "MapGenerator" );
        generator.MapGenerated += OnMapGenerated;
        generator.Generate( grid );

        _gm.ReportReady( "Level01", $"seed={grid.GetSeed()}, start={grid.Start}, end={grid.End}" );
    }

    public override void _ExitTree ()
    {
        if ( _gm != null )
        {
            _gm.StateChanged -= OnStateChanged;
        }
    }

    private void OnStateChanged ( int previous, int current )
    {
        GD.Print( $"Level01: state_changed {(GameManager.State)previous} -> {(GameManager.State)current}" );
    }

    private void OnMapGenerated ( Vector2I start, Vector2I end, int pathLength )
    {
        GD.Print( $"Level01: map_generated start={start} end={end} pathLength={pathLength}" );
    }
}
