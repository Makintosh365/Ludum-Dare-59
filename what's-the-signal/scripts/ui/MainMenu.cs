using Godot;

public partial class MainMenu : Control
{
    public override void _Ready ()
    {
        var gm = GetNode<GameManager>( "/root/GameManager" );
        gm.ReportReady( "MainMenu" );
        GetNode<Button>( "%StartButton" ).Pressed += () =>
        {
            GD.Print( "MainMenu: Start pressed" );
            gm.LoadLevel();
        };
        GetNode<Button>( "%QuitButton" ).Pressed += () =>
        {
            GD.Print( "MainMenu: Quit pressed" );
            gm.QuitGame();
        };
    }
}
