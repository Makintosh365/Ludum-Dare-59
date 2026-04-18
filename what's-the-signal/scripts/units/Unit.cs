using Godot;
using System;

public abstract partial class Unit : Node2D, IDamageable
{
    [Signal]
    public delegate void MovedEventHandler ( Vector2I from, Vector2I to );

    [Signal]
    public delegate void DamagedEventHandler ( int amount, int healthAfter );

    [Signal]
    public delegate void DiedEventHandler ();

    [Export] public int MaxHealth { get; set; } = 10;
    [Export] public int Damage { get; set; } = 1;
    [Export] public float AttackSpeed { get; set; } = 1.0f;
    [Export] public int Defense { get; set; } = 0;

    public int Health { get; private set; }
    public bool IsAlive => Health > 0;

    public Vector2I Coords { get; protected set; }
    public Grid Grid { get; protected set; }

    public override void _Ready ()
    {
        Health = MaxHealth;
        QueueRedraw();
    }

    public void PlaceOn ( Grid grid, Vector2I coords )
    {
        if ( grid == null )
        {
            GD.PushWarning( $"Unit {Name}: PlaceOn called with null grid" );
            return;
        }
        if ( !grid.InBounds( coords ) )
        {
            GD.PushWarning( $"Unit {Name}: PlaceOn coords {coords} out of bounds" );
            return;
        }
        var cell = grid.GetCell( coords );
        if ( !cell.IsWalkable )
        {
            GD.PushWarning( $"Unit {Name}: PlaceOn cell {coords} is not walkable" );
        }
        if ( cell.Contents != null && cell.Contents != this )
        {
            GD.PushWarning( $"Unit {Name}: PlaceOn cell {coords} already occupied by {cell.Contents}" );
        }

        Grid = grid;
        Coords = coords;
        cell.Contents = this;
        Position = grid.CellToWorld( coords );
        OnPlaced( coords );
    }

    protected virtual void OnPlaced ( Vector2I coords )
    {
        if ( Grid == null )
        {
            return;
        }
        var cell = Grid.GetCell( coords );
        if ( cell == null )
        {
            return;
        }
        Visible = cell.Visibility == CellVisibility.Full;
    }

    public bool TryMove ( Vector2I target )
    {
        if ( Grid == null )
        {
            return false;
        }
        if ( !Grid.CanMove( Coords, target ) )
        {
            return false;
        }
        var destination = Grid.GetCell( target );
        if ( destination.Contents != null )
        {
            return false;
        }

        var from = Coords;
        Grid.GetCell( from ).Contents = null;
        destination.Contents = this;
        Coords = target;
        Position = Grid.CellToWorld( target );
        EmitSignal( SignalName.Moved, from, target );
        return true;
    }

    public bool TryStep ( Vector2I direction )
    {
        return TryMove( Coords + direction );
    }

    public void TakeDamage ( int amount, object source = null )
    {
        if ( !IsAlive || amount <= 0 )
        {
            return;
        }
        int reduced = Math.Max( 0, amount - Defense );
        if ( reduced == 0 )
        {
            return;
        }
        Health = Math.Clamp( Health - reduced, 0, MaxHealth );
        EmitSignal( SignalName.Damaged, reduced, Health );
        if ( Health == 0 )
        {
            Die( source );
        }
    }

    protected virtual void Die ( object killer )
    {
        if ( Grid != null )
        {
            var cell = Grid.GetCell( Coords );
            if ( cell != null && cell.Contents == this )
            {
                cell.Contents = null;
            }
        }
        EmitSignal( SignalName.Died );
        QueueFree();
    }
}
