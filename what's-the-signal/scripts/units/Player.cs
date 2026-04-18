using Godot;

public partial class Player : Unit
{
    [Signal]
    public delegate void CoinsChangedEventHandler ( int newTotal );

    [Export] public Color BodyColor { get; set; } = new Color( 0.3f, 0.7f, 1.0f );

    public int Coins { get; private set; } = 0;

    public void AddCoins ( int amount )
    {
        if ( amount <= 0 )
        {
            return;
        }
        Coins += amount;
        EmitSignal( SignalName.CoinsChanged, Coins );
    }

    public override void _Draw ()
    {
        const float radius = 10f;
        DrawCircle( Vector2.Zero, radius, BodyColor );
        DrawArc( Vector2.Zero, radius, 0, Mathf.Tau, 24, Colors.White, 1.5f );
    }
}
