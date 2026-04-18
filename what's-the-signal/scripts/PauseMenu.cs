using Godot;

public partial class PauseMenu : CanvasLayer
{
    public override void _Ready ()
    {
        var gm = GetNode<GameManager>( "/root/GameManager" );
        GetNode<Button>( "%ResumeButton" ).Pressed += () => gm.ChangeState( GameManager.State.Gameplay );
        GetNode<Button>( "%RestartButton" ).Pressed += gm.RestartLevel;
        GetNode<Button>( "%MainMenuButton" ).Pressed += gm.LoadMainMenu;
        GetNode<Button>( "%QuitButton" ).Pressed += gm.QuitGame;
    }
}
