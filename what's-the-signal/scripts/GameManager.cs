using Godot;
using System.Collections.Generic;

public partial class GameManager : Node
{
    [Signal]
    public delegate void StateChangedEventHandler ( int previous, int current );

    public enum State { Boot, MainMenu, Loading, Gameplay, Paused, Victory, Defeat }

    [Export] public PackedScene MainMenuScene { get; set; }
    [Export] public PackedScene GameplayScene { get; set; }
    [Export] public PackedScene PauseMenuScene { get; set; }
    [Export] public PackedScene VictoryScreenScene { get; set; }
    [Export] public PackedScene DefeatScreenScene { get; set; }

    public State CurrentState => _state;

    public override void _Ready ()
    {
        ProcessMode = ProcessModeEnum.Always;
    }

    public override void _UnhandledInput ( InputEvent @event )
    {
        if ( @event.IsActionPressed( "ui_cancel" ) )
            TogglePause();
    }

    public async void LoadLevel ()
    {
        if ( GameplayScene == null )
        {
            GD.PushWarning( "GameManager: GameplayScene is not set" );
            return;
        }

        if ( !ChangeState( State.Loading ) )
        {
            return;
        }

        await ToSignal( GetTree(), SceneTree.SignalName.ProcessFrame );
        GetTree().ChangeSceneToPacked( GameplayScene );
        await ToSignal( GetTree(), SceneTree.SignalName.ProcessFrame );
        ChangeState( State.Gameplay );
    }

    public void TogglePause ()
    {
        switch ( _state )
        {
            case State.Gameplay: ChangeState( State.Paused ); break;
            case State.Paused: ChangeState( State.Gameplay ); break;
        }
    }

    public void TriggerVictory () => ChangeState( State.Victory );

    public void TriggerDefeat () => ChangeState( State.Defeat );

    public void RestartLevel () => LoadLevel();

    public void LoadMainMenu ()
    {
        if ( MainMenuScene == null )
        {
            GD.PushWarning( "GameManager: MainMenuScene is not set" );
            return;
        }
        if ( !ChangeState( State.MainMenu ) )
        {
            return;
        }

        GetTree().ChangeSceneToPacked( MainMenuScene );
    }

    public void QuitGame () => GetTree().Quit();

    public bool ChangeState ( State newState )
    {
        if ( newState == _state )
        {
            return false;
        }
        if ( !ValidTransitions.TryGetValue( _state, out var allowed ) || System.Array.IndexOf( allowed, newState ) < 0 )
        {
            GD.PushWarning( $"GameManager: invalid transition {_state} -> {newState}" );
            return false;
        }
        var previous = _state;
        _state = newState;
        EmitSignal( SignalName.StateChanged, (int)previous, (int)newState );
        ApplyState( previous, newState );
        return true;
    }

    private static readonly Dictionary<State, State[]> ValidTransitions = new()
    {
        [ State.Boot ] = new[] { State.MainMenu, State.Loading },
        [ State.MainMenu ] = new[] { State.Loading },
        [ State.Loading ] = new[] { State.Gameplay, State.MainMenu },
        [ State.Gameplay ] = new[] { State.Paused, State.Victory, State.Defeat, State.Loading, State.MainMenu },
        [ State.Paused ] = new[] { State.Gameplay, State.Loading, State.MainMenu },
        [ State.Victory ] = new[] { State.Loading, State.MainMenu },
        [ State.Defeat ] = new[] { State.Loading, State.MainMenu },
    };

    private State _state = State.Boot;
    private Node _overlay;

    private void ApplyState ( State previous, State current )
    {
        if ( previous is State.Paused or State.Victory or State.Defeat )
        {
            ClearOverlay();
            if ( current is not State.Paused and not State.Victory and not State.Defeat )
            {
                GetTree().Paused = false;
            }
        }

        switch ( current )
        {
            case State.Paused:
                GetTree().Paused = true;
                ShowOverlay( PauseMenuScene );
                break;
            case State.Victory:
                GetTree().Paused = true;
                ShowOverlay( VictoryScreenScene );
                break;
            case State.Defeat:
                GetTree().Paused = true;
                ShowOverlay( DefeatScreenScene );
                break;
            case State.Gameplay:
                GetTree().Paused = false;
                break;
        }
    }

    private void ShowOverlay ( PackedScene scene )
    {
        if ( scene == null )
        {
            GD.PushWarning( "GameManager: overlay scene is not set" );
            return;
        }

        ClearOverlay();
        _overlay = scene.Instantiate();
        GetTree().Root.AddChild( _overlay );
    }

    private void ClearOverlay ()
    {
        if ( GodotObject.IsInstanceValid( _overlay ) )
        {
            _overlay.QueueFree();
        }
        _overlay = null;
    }
}
