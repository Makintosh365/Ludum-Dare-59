using Godot;

public partial class MainMenu : Control
{
    public override void _Ready ()
    {
        var gm = GetNode<GameManager>( "/root/GameManager" );
        GetNode<Button>( "%StartButton" ).Pressed += () => gm.LoadLevel();
        GetNode<Button>( "%QuitButton" ).Pressed += gm.QuitGame;
    }
}
