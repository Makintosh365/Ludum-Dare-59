using Godot;

[GlobalClass]
public partial class CameraConfig : Resource
{
    [Export( PropertyHint.Range, "0.1,40.0,0.1" )]
    public float SmoothSpeed { get; set; } = 12.0f;

    [Export] public Vector2 TargetOffset { get; set; } = Vector2.Zero;

    [Export( PropertyHint.Range, "0.0,16.0,0.1" )]
    public float SnapDistance { get; set; } = 0.5f;
}
