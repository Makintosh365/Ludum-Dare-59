using Godot;

public partial class FollowCamera : Camera2D
{
	[Export] public CameraConfig Config { get; set; }

	private const string DefaultCameraConfigPath = "res://configs/default_camera.tres";

	private Node2D _target;
	private Vector2 _desiredPosition;
	private bool _hasTarget;

	public override void _Ready ()
	{
		MakeCurrent();
		EnsureConfig();
	}

	public override void _ExitTree ()
	{
		if ( _target is Player prev )
		{
			prev.Moved -= OnPlayerMoved;
		}
	}

	public void SetTarget ( Node2D target, bool snap = true )
	{
		if ( _target is Player prev )
		{
			prev.Moved -= OnPlayerMoved;
		}

		_target = target;
		_hasTarget = target != null;

		if ( target is Player next )
		{
			next.Moved += OnPlayerMoved;
		}

		if ( !_hasTarget )
		{
			return;
		}

		var config = EnsureConfig();
		_desiredPosition = target.GlobalPosition + config.TargetOffset;

		if ( snap )
		{
			SnapToTarget();
		}
	}

	public void SnapToTarget ()
	{
		if ( !_hasTarget )
		{
			return;
		}
		var config = EnsureConfig();
		_desiredPosition = _target.GlobalPosition + config.TargetOffset;
		GlobalPosition = _desiredPosition;
		ResetSmoothing();
	}

	public override void _Process ( double delta )
	{
		if ( !_hasTarget || Config == null )
		{
			return;
		}

		var diff = _desiredPosition - GlobalPosition;
		float snap = Config.SnapDistance;
		if ( diff.LengthSquared() <= snap * snap )
		{
			GlobalPosition = _desiredPosition;
			return;
		}

		float t = 1f - Mathf.Exp( -Config.SmoothSpeed * (float)delta );
		GlobalPosition = GlobalPosition.Lerp( _desiredPosition, t );
	}

	private void OnPlayerMoved ( Vector2I from, Vector2I to )
	{
		if ( _target == null )
		{
			return;
		}
		_desiredPosition = _target.GlobalPosition + EnsureConfig().TargetOffset;
	}

	private CameraConfig EnsureConfig ()
	{
		if ( Config != null )
		{
			return Config;
		}
		if ( ResourceLoader.Exists( DefaultCameraConfigPath ) )
		{
			Config = ResourceLoader.Load<CameraConfig>( DefaultCameraConfigPath );
		}
		if ( Config == null )
		{
			GD.PushWarning( $"FollowCamera {Name}: CameraConfig not set and default missing, using inline defaults" );
			Config = new CameraConfig();
		}
		return Config;
	}
}
