using Godot;

public partial class Level01 : Node2D
{
    public override void _Ready ()
    {
        var gm = GetNode<GameManager>( "/root/GameManager" );
        GetNode<Button>( "%VictoryButton" ).Pressed += gm.TriggerVictory;
        GetNode<Button>( "%DefeatButton" ).Pressed += gm.TriggerDefeat;
        gm.StateChanged += OnStateChanged;
    }

    private void OnStateChanged ( int previous, int current )
    {
        GD.Print( $"Level01: state_changed {previous} -> {current}" );
    }
}
