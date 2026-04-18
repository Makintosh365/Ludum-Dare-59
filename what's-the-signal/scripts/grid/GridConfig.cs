using Godot;

[GlobalClass]
public partial class GridConfig : Resource
{
    [Export] public int Width { get; set; } = 30;
    [Export] public int Height { get; set; } = 20;
    [Export] public int CellSize { get; set; } = 32;
    [Export] public string TexturesRoot { get; set; } = "res://assets/cells/";
    [Export] public bool DrawDebugOverlay { get; set; } = true;
    [Export] public long SeedInput { get; set; } = 0;
}
