using Godot;

public partial class Enemy : Unit
{
    [Export] public Color BodyColor { get; set; } = new Color( 1.0f, 0.3f, 0.3f );
    [Export] public int CoinReward { get; set; } = 1;

    public override void _Draw ()
    {
        const float half = 9f;
        var rect = new Rect2( -half, -half, half * 2, half * 2 );
        DrawRect( rect, BodyColor, true );
        DrawRect( rect, Colors.White, false );
    }

    protected override void Die ( object killer )
    {
        if ( killer is Player player )
        {
            player.AddCoins( CoinReward );
        }
        base.Die( killer );
    }
}
