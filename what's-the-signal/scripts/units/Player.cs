using Godot;

public partial class Player : Unit
{
    public enum InputDuringStep
    {
        Ignore,
        BufferOne,
    }

    [Signal]
    public delegate void CoinsChangedEventHandler ( int newTotal );

    [Signal]
    public delegate void MoveBlockedEventHandler ( Vector2I targetCell, string reason );

    [Export] public Color BodyColor { get; set; } = new Color( 0.3f, 0.7f, 1.0f );

    [Export( PropertyHint.Range, "0.01,2.0,0.01" )]
    public float StepDuration { get; set; } = 0.15f;

    [Export] public Tween.TransitionType StepTransition { get; set; } = Tween.TransitionType.Sine;
    [Export] public Tween.EaseType StepEase { get; set; } = Tween.EaseType.InOut;

    [Export] public InputDuringStep BufferingMode { get; set; } = InputDuringStep.BufferOne;

    [Export] public SightConfig SightConfig { get; set; }

    private const string DefaultSightConfigPath = "res://configs/default_sight.tres";

    public int Coins { get; private set; } = 0;

    private bool _isAnimating;
    private Vector2I? _bufferedDirection;

    public void AddCoins ( int amount )
    {
        if ( amount <= 0 )
        {
            return;
        }
        Coins += amount;
        EmitSignal( SignalName.CoinsChanged, Coins );
    }

    protected override void OnPlaced ( Vector2I coords )
    {
        var config = EnsureSightConfig();
        if ( Grid != null )
        {
            Grid.UpdateVisibilityFrom( coords, config.BrightRadius, config.DimRadius, config.RevealAllCells );
        }
        Visible = true;
    }

    private SightConfig EnsureSightConfig ()
    {
        if ( SightConfig != null )
        {
            return SightConfig;
        }
        if ( ResourceLoader.Exists( DefaultSightConfigPath ) )
        {
            SightConfig = ResourceLoader.Load<SightConfig>( DefaultSightConfigPath );
        }
        if ( SightConfig == null )
        {
            GD.PushWarning( $"Player {Name}: SightConfig not set and default missing, using inline defaults" );
            SightConfig = new SightConfig();
        }
        return SightConfig;
    }

    public override void _UnhandledInput ( InputEvent @event )
    {
        if ( !IsAlive || Grid == null )
        {
            return;
        }
        Vector2I direction;
        if ( @event.IsActionPressed( "move_up" ) )
        {
            direction = new Vector2I( 0, -1 );
        }
        else if ( @event.IsActionPressed( "move_down" ) )
        {
            direction = new Vector2I( 0, 1 );
        }
        else if ( @event.IsActionPressed( "move_left" ) )
        {
            direction = new Vector2I( -1, 0 );
        }
        else if ( @event.IsActionPressed( "move_right" ) )
        {
            direction = new Vector2I( 1, 0 );
        }
        else
        {
            return;
        }
        GetViewport().SetInputAsHandled();
        RequestStep( direction );
    }

    public void RequestStep ( Vector2I direction )
    {
        if ( Grid == null || direction == Vector2I.Zero )
        {
            return;
        }

        if ( _isAnimating )
        {
            if ( BufferingMode == InputDuringStep.BufferOne )
            {
                _bufferedDirection = direction;
            }
            return;
        }

        var target = Coords + direction;

        if ( !Grid.InBounds( target ) )
        {
            EmitSignal( SignalName.MoveBlocked, target, "out_of_bounds" );
            return;
        }

        var destination = Grid.GetCell( target );
        if ( !destination.IsWalkable )
        {
            EmitSignal( SignalName.MoveBlocked, target, "not_walkable" );
            return;
        }
        if ( destination.Contents != null )
        {
            EmitSignal( SignalName.MoveBlocked, target, "occupied" );
            return;
        }

        var from = Coords;
        Grid.GetCell( from ).Contents = null;
        destination.Contents = this;
        Coords = target;
        var sight = EnsureSightConfig();
        Grid.UpdateVisibilityFrom( target, sight.BrightRadius, sight.DimRadius, sight.RevealAllCells );

        _isAnimating = true;
        var tween = CreateTween();
        tween.SetTrans( StepTransition );
        tween.SetEase( StepEase );
        tween.TweenProperty( this, "position", Grid.CellToWorld( target ), StepDuration );
        tween.Finished += () => OnStepFinished( from, target );
    }

    private void OnStepFinished ( Vector2I from, Vector2I to )
    {
        _isAnimating = false;
        EmitSignal( SignalName.Moved, from, to );

        if ( _bufferedDirection.HasValue )
        {
            var next = _bufferedDirection.Value;
            _bufferedDirection = null;
            RequestStep( next );
        }
    }

    public override void _Draw ()
    {
        const float radius = 10f;
        DrawCircle( Vector2.Zero, radius, BodyColor );
        DrawArc( Vector2.Zero, radius, 0, Mathf.Tau, 24, Colors.White, 1.5f );
    }
}
