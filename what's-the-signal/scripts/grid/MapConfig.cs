using Godot;

[GlobalClass]
public partial class MapConfig : Resource
{
    [Export] public int MinPathLength { get; set; } = 200;
    [Export] public int MaxPathLength { get; set; } = 250;
    [Export] public int MaxGenerationAttempts { get; set; } = 10;
    [Export] public long[] FallbackSeeds { get; set; } = System.Array.Empty<long>();

    [Export( PropertyHint.Range, "0,1,0.05" )]
    public float TurnChance { get; set; } = 0.2f;

    [Export( PropertyHint.Range, "0,1,0.05" )]
    public float BranchChance { get; set; } = 0.25f;

    [Export] public Vector2I StartCoords { get; set; } = new Vector2I( -1, -1 );

    [Export] public string[] TerrainKinds { get; set; } = new string[] { "forest", "mountain" };
    [Export] public float[] TerrainWeights { get; set; } = new float[] { 0.7f, 0.3f };

    [Export] public int MaxPathNeighbors { get; set; } = 3;
    [Export] public bool ForbidDoubleWidth { get; set; } = true;

    [Export] public int MinJunctions { get; set; } = 0;
    [Export] public int MaxJunctions { get; set; } = 0;
    [Export] public int MaxJunctionNeighbors { get; set; } = 4;
}
