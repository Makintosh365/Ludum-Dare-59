using Godot;

public partial class Boot : Node
{
    public override void _Ready ()
    {
        var gm = GetNode<GameManager>( "/root/GameManager" );
        gm.ReportReady( "Boot", "handing off to MainMenu" );
        gm.ChangeState( GameManager.State.MainMenu );
        if ( gm.MainMenuScene != null )
        {
            GetTree().ChangeSceneToPacked( gm.MainMenuScene );
        }
        else
        {
            GD.PushWarning( "Boot: GameManager.MainMenuScene is not set" );
        }
    }
}
