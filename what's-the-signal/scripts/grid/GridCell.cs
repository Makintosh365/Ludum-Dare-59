using Godot;

public class GridCell
{
    public Vector2I Coords { get; }

    public bool IsWalkable { get; set; } = true;
    public bool IsExplored { get; set; } = false;

    public string Kind { get; set; } = CellKinds.Walkable;

    public int DistanceFromStart { get; set; } = -1;

    public object Contents { get; set; }

    public GridCell ( Vector2I coords )
    {
        Coords = coords;
    }
}
