class_name VhsCrtOverlay
extends CanvasLayer

@export var screen_rect_path: NodePath = ^"ScreenRect"
@export var config: VhsCrtConfig

var _screen_rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen_rect = get_node_or_null(screen_rect_path) as ColorRect
	if _screen_rect == null:
		push_warning("VhsCrtOverlay: ScreenRect not found at %s" % screen_rect_path)
		return
	_material = _screen_rect.material as ShaderMaterial
	if _material == null:
		push_warning("VhsCrtOverlay: ScreenRect has no ShaderMaterial")
		return
	apply_config()


func set_config(new_config: VhsCrtConfig) -> void:
	config = new_config
	apply_config()


func apply_config() -> void:
	if _material == null or config == null:
		return

	_material.set_shader_parameter(&"overlay", config.overlay)

	_material.set_shader_parameter(&"scanlines_opacity", config.scanlines_opacity)
	_material.set_shader_parameter(&"scanlines_width", config.scanlines_width)

	_material.set_shader_parameter(&"grille_opacity", config.grille_opacity)

	_material.set_shader_parameter(&"resolution", config.resolution)
	_material.set_shader_parameter(&"pixelate", config.pixelate)

	_material.set_shader_parameter(&"roll", config.roll)
	_material.set_shader_parameter(&"roll_speed", config.roll_speed)
	_material.set_shader_parameter(&"roll_size", config.roll_size)
	_material.set_shader_parameter(&"roll_variation", config.roll_variation)
	_material.set_shader_parameter(&"distort_intensity", config.distort_intensity)

	_material.set_shader_parameter(&"noise_opacity", config.noise_opacity)
	_material.set_shader_parameter(&"noise_speed", config.noise_speed)

	_material.set_shader_parameter(&"static_noise_intensity", config.static_noise_intensity)

	_material.set_shader_parameter(&"aberration", config.aberration)
	_material.set_shader_parameter(&"brightness", config.brightness)
	_material.set_shader_parameter(&"discolor", config.discolor)

	_material.set_shader_parameter(&"warp_amount", config.warp_amount)
	_material.set_shader_parameter(&"clip_warp", config.clip_warp)

	_material.set_shader_parameter(&"vignette_intensity", config.vignette_intensity)
	_material.set_shader_parameter(&"vignette_opacity", config.vignette_opacity)


func set_enabled(enabled: bool) -> void:
	visible = enabled


func set_uniform(uniform_name: StringName, value) -> void:
	if _material == null:
		return
	_material.set_shader_parameter(uniform_name, value)
