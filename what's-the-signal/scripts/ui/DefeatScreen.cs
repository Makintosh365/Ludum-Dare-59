using Godot;

public partial class DefeatScreen : CanvasLayer
{
	public override void _Ready()
	{
		var gm = GetNode<GameManager>("/root/GameManager");
		GetNode<Button>("%RestartButton").Pressed += gm.RestartLevel;
		GetNode<Button>("%MainMenuButton").Pressed += gm.LoadMainMenu;
	}
}
