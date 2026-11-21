extends Node
## Quality tier manager. Autoloaded as "Quality" (see project.godot).
## High: full resolution scale, rain splashes, light shafts, MSAA.
## Low: 0.62 resolution scale, no splashes, no shafts, no MSAA, thinner rain.
## Picks automatically from measured FPS after the opening shot; the pause
## menu can override (Auto / Low / High) at any time.

signal tier_changed(tier: String)

const HIGH := "High"
const LOW := "Low"

var tier := HIGH
var override := "Auto"  # Auto | Low | High
var _samples: Array[float] = []
var _auto_decided := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply(LOW if _guess_low_end_device() else HIGH)


## The pause menu calls this: "Auto" re-enables measurement, else force a tier.
func set_override(mode: String) -> void:
	override = mode
	match mode:
		LOW:
			_apply(LOW)
		HIGH:
			_apply(HIGH)
		_:
			_auto_decided = false
			_samples.clear()


func _process(_delta: float) -> void:
	if override != "Auto" or _auto_decided:
		return
	if InputBus.locked:
		return  # measure gameplay, not the opening
	_samples.append(Engine.get_frames_per_second())
	if _samples.size() == 180:  # ~3 s of samples
		var worst := 60.0
		for s in _samples:
			worst = minf(worst, s)
		# A single stutter frame should not demote the whole game.
		var avg := 0.0
		for s in _samples:
			avg += s
		avg /= _samples.size()
		_apply(LOW if avg < 50.0 else HIGH)
		_auto_decided = true
		Log.info("quality: auto-picked %s (avg %.0f fps, min %.0f)" % [tier, avg, worst])


func _apply(new_tier: String) -> void:
	if new_tier == tier:
		return
	tier = new_tier
	var window := get_window()
	match tier:
		HIGH:
			window.content_scale_factor = 1.0
			get_viewport().scaling_3d_scale = 1.0
			get_viewport().msaa_3d = Viewport.MSAA_2X
		LOW:
			window.content_scale_factor = 1.0
			get_viewport().scaling_3d_scale = 0.62
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	tier_changed.emit(tier)
	Log.info("quality: tier %s" % tier)


func _guess_low_end_device() -> bool:
	# Start conservative on phones: the auto-measure promotes to High if fps holds.
	return OS.has_feature("mobile")
