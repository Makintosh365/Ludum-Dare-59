using Godot;

public partial class Level01 : Node2D
{
    private GameManager _gm;
    private Grid _grid;
    private Player _player;
    private Enemy _enemy;

    public override void _Ready ()
    {
        _gm = GetNode<GameManager>( "/root/GameManager" );
        GetNode<Button>( "%VictoryButton" ).Pressed += _gm.TriggerVictory;
        GetNode<Button>( "%DefeatButton" ).Pressed += _gm.TriggerDefeat;
        _gm.StateChanged += OnStateChanged;

        _grid = GetNode<Grid>( "Grid" );
        var generator = GetNode<MapGenerator>( "MapGenerator" );
        generator.MapGenerated += OnMapGenerated;
        generator.Generate( _grid );

        _gm.ReportReady( "Level01", $"seed={_grid.GetSeed()}, start={_grid.Start}, end={_grid.End}" );
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

        _player = new Player { Name = "Player" };
        AddChild( _player );
        _player.PlaceOn( _grid, start );
        _player.Moved        += ( from, to ) => GD.Print( $"Level01: player moved {from} -> {to}" );
        _player.Damaged      += ( amt, hp )  => GD.Print( $"Level01: player damaged {amt} hp={hp}" );
        _player.Died         += ()           => GD.Print( "Level01: player died" );
        _player.CoinsChanged += total        => GD.Print( $"Level01: player coins={total}" );

        _enemy = new Enemy { Name = "Enemy", MaxHealth = 3, CoinReward = 5 };
        AddChild( _enemy );
        _enemy.PlaceOn( _grid, end );
        _enemy.Died += () => GD.Print( "Level01: enemy died" );

        bool contentsOk = _grid.GetCell( start ).Contents == _player
                       && _grid.GetCell( end ).Contents == _enemy;
        GD.Print( contentsOk ? "Level01: contents ok" : "Level01: contents MISMATCH" );
    }
}
