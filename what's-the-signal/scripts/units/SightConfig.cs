using Godot;

[GlobalClass]
public partial class SightConfig : Resource
{
    [Export( PropertyHint.Range, "0.0,64.0,0.1" )]
    public float BrightRadius { get; set; } = 1f;

    [Export( PropertyHint.Range, "0.0,64.0,0.1" )]
    public float DimRadius { get; set; } = 2f;

    [Export] public bool RevealAllCells { get; set; } = false;
}
