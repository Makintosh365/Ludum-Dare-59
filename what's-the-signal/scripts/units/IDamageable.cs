public interface IDamageable
{
    int Health { get; }
    int MaxHealth { get; }
    bool IsAlive { get; }
    void TakeDamage ( int amount, object source = null );
}
