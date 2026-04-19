class_name VhsCrtConfig
extends Resource

# When true the shader samples SCREEN_TEXTURE via SCREEN_UV — required for our
# full-screen CanvasLayer overlay. Set false only if the material is assigned
# to a regular Sprite/ColorRect used as an object, not a post-fx overlay.
@export var overlay: bool = true

@export_group("Scanlines")
@export_range(0.0, 1.0, 0.01) var scanlines_opacity: float = 0.5
@export_range(0.0, 0.5, 0.01) var scanlines_width: float = 0.25

@export_group("Aperture Grille (RGB subpixels)")
@export_range(0.0, 1.0, 0.01) var grille_opacity: float = 0.3

@export_group("Resolution / Pixelate")
# Virtual resolution used by scanlines, grille, and pixelation.
@export var resolution: Vector2 = Vector2(640.0, 480.0)
@export var pixelate: bool = false

@export_group("Roll / Distortion (animated)")
@export var roll: bool = false
@export var roll_speed: float = 8.0
@export_range(0.0, 100.0, 0.1) var roll_size: float = 15.0
@export_range(0.1, 5.0, 0.05) var roll_variation: float = 1.8
@export_range(0.0, 0.2, 0.001) var distort_intensity: float = 0.05

@export_group("Tape Noise (animated band)")
@export_range(0.0, 1.0, 0.01) var noise_opacity: float = 0.0
@export var noise_speed: float = 5.0

@export_group("Static Grain")
@export_range(0.0, 1.0, 0.01) var static_noise_intensity: float = 0.03

@export_group("Color")
@export_range(-1.0, 1.0, 0.005) var aberration: float = 0.05
@export var brightness: float = 1.3
@export var discolor: bool = true

@export_group("Warp / Curvature")
@export_range(0.0, 5.0, 0.05) var warp_amount: float = 0.8
@export var clip_warp: bool = false

@export_group("Vignette")
@export var vignette_intensity: float = 0.4
@export_range(0.0, 1.0, 0.01) var vignette_opacity: float = 0.5
