extends Node

const _SFX_DIR := "res://assets/audio/sfx/"
const _SETTINGS_PATH := "user://settings.cfg"
const _SECTION := "audio"
const _KEY_VOLUME := "master_volume"
const _STEP_THROTTLE_MS := 80

const _FILES := {
	"button":   "PressButton.mp3",
	"hit":      "Hit.mp3",
	"reward":   "ClaimingTheReward.mp3",
	"step":     "step.mp3",
	"win_lose": "win-lose.mp3",
}

# Per-sound volume trim in dB.
const _VOLUME_DB := {
	"step": -10.0,
}

signal master_volume_changed(value: float)

var _streams: Dictionary = {}
var _players: Dictionary = {}
var _master_volume: float = 1.0
var _last_step_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	_build_players()
	_load_settings()
	_apply_master_volume()
	call_deferred("_prewarm_players")


func _load_streams() -> void:
	for key in _FILES:
		var path: String = _SFX_DIR + String(_FILES[key])
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
		else:
			push_warning("AudioManager: missing %s" % path)


func _build_players() -> void:
	for key in _FILES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.stream = _streams.get(key, null)
		p.volume_db = float(_VOLUME_DB.get(key, 0.0))
		add_child(p)
		_players[key] = p


func _prewarm_players() -> void:
	# Touch every MP3 decoder once so the first real .play() doesn't pay
	# the decode-startup cost (perceived as a click->sound delay).
	for key in _players:
		var p: AudioStreamPlayer = _players[key]
		if p == null or p.stream == null:
			continue
		var prev_db := p.volume_db
		p.volume_db = -80.0
		p.play()
		p.stop()
		p.volume_db = prev_db


func _play(key: String) -> void:
	var p: AudioStreamPlayer = _players.get(key, null)
	if p == null or p.stream == null:
		return
	p.play(0.0)


func play_button() -> void:
	_play("button")


func play_hit() -> void:
	_play("hit")


func play_reward() -> void:
	_play("reward")


func play_win_lose() -> void:
	_play("win_lose")


func play_step() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_step_ms < _STEP_THROTTLE_MS:
		return
	_last_step_ms = now
	_play("step")


# ---------- Master volume ----------

func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume()
	_save_settings()
	master_volume_changed.emit(_master_volume)


func get_master_volume() -> float:
	return _master_volume


func _apply_master_volume() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	if _master_volume <= 0.0001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(_master_volume))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SETTINGS_PATH) == OK:
		_master_volume = clampf(float(cfg.get_value(_SECTION, _KEY_VOLUME, 1.0)), 0.0, 1.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_SETTINGS_PATH)
	cfg.set_value(_SECTION, _KEY_VOLUME, _master_volume)
	cfg.save(_SETTINGS_PATH)


# ---------- Button SFX wiring ----------

func wire_button(btn: Button) -> void:
	if btn == null:
		return
	if not btn.pressed.is_connected(play_button):
		btn.pressed.connect(play_button)


func register_buttons(root: Node) -> void:
	if root == null:
		return
	if root is Button:
		wire_button(root)
	for c in root.get_children():
		register_buttons(c)
