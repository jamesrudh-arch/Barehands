extends Node
## Player settings, autoloaded as "Settings". Separate from save.json so
## wiping a save never wipes comfort settings. Everything here is persisted
## to user://settings.json the moment it changes. Stage A owns the control
## half; future stages add their own keys here.
##
## Keys (with defaults):
##   scheme        "floating" | "fixed" | "dpad" | "drag"   movement scheme
##   sensitivity   1.0   stick sensitivity multiplier (0.4 .. 2.0)
##   deadzone      0.15  stick dead zone fraction (0.05 .. 0.35)
##   curve         1.7   response curve exponent (1.0 linear .. 3.0 slow start)
##   smoothing     0.07  smoothing time constant seconds (0 .. 0.2)
##   stick_scale   1.0   on-screen stick size multiplier (0.7 .. 1.5)
##   cam_drag      true  dragging the right half of the screen turns the camera
##   cam_speed     1.0   camera drag speed (0.4 .. 2.0)
##   auto_sprint   false sprint by pushing the stick to its edge
##   snap8         false snap movement to 8 directions
##   haptics_on    true  master haptics switch
##   haptic_str    1.0   haptics strength (0 .. 1)
##   preset        "classic"          layout preset name
##   layout        {}                 per-button overrides from the editor
##   opacity       0.85               HUD control opacity (0.3 .. 1.0)
##   hints         {}                 one-time move prompts already shown

signal changed(key: String)

const PATH := "user://settings.json"

const DEFAULTS := {
	"scheme": "floating",
	"button_scheme": "classic",
	"sensitivity": 1.0,
	"deadzone": 0.15,
	"curve": 1.7,
	"smoothing": 0.07,
	"stick_scale": 1.0,
	"cam_drag": true,
	"cam_speed": 1.0,
	"auto_sprint": false,
	"snap8": false,
	"left_handed": false,
	"first_run_done": false,
	"haptics_on": true,
	"haptic_str": 1.0,
	"preset": "classic",
	"layout": {},
	"opacity": 0.85,
	"button_scale": 1.0,
	"shake_scale": 1.0,
	"difficulty": "street",  # street as written / hard / brutal
	"hints": {},
	# B18: the radar + map (Part 6B) and the hero locator (Part 1.3)
	"radar_on": true,         # the round radar; false hides it
	"radar_scale": 1.0,       # 0.75..1.4 of the ~20%-height base
	"radar_north_up": false,  # true = north-up instead of camera-rotating
	"route_line_3d": false,   # the optional ground route ribbon
	"hero_locator": true,     # the bright ring + rim light under the hero
	"hero_rim": 1.8,          # rim light energy, 0..3
	# B18 6C: the never-lost guidance
	"sonar_on": true,         # the panned objective ping
	# B18.3: voice + narration (subtitles always show)
	"narrator_on": true,      # spoken lines when the platform TTS allows
	"skip_intro": false,      # jump straight to the menu at launch
}

var _d: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	load_all()


func value(key: String):
	return _d.get(key, DEFAULTS.get(key))


func set_value(key: String, value) -> void:
	if _d.get(key) == value:
		return
	_d[key] = value
	_write()
	changed.emit(key)


func set_hint_done(id: String) -> void:
	var h: Dictionary = _d.get("hints", {})
	if h.get(id, false):
		return
	h[id] = true
	_d["hints"] = h
	_write()


func hint_done(id: String) -> bool:
	return _d.get("hints", {}).get(id, false)


## Layout overrides for one HUD button: {"x": -150, "y": -100, "scale": 1.2,
## "opacity": 1.0} - x/y are pixels from the button's default anchor.
## The difficulty levers (bible 14 defaults are STREET, untouched).
## name -> the active tier's multiplier; every lever defaults 1.0.
func diff_mult(lever: String) -> float:
	var d := str(value("difficulty"))
	if d == "hard":
		return float(Tuning.v("hard_" + lever))
	if d == "brutal":
		return float(Tuning.v("brutal_" + lever))
	return 1.0


func layout_for(button: String) -> Dictionary:
	return _d.get("layout", {}).get(button, {})


func set_layout_for(button: String, over: Dictionary) -> void:
	var l: Dictionary = _d.get("layout", {})
	l[button] = over
	_d["layout"] = l
	_write()
	changed.emit("layout")


func reset_layout() -> void:
	_d["layout"] = {}
	_d["preset"] = "classic"
	_write()
	changed.emit("layout")


func load_all() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is not Dictionary:
		Log.warn("Settings: file unreadable, using defaults")
		return
	for k in DEFAULTS:
		if parsed.has(k):
			_d[k] = parsed[k]
	Log.info("Settings: loaded (scheme %s, dz %.2f)" % [str(_d["scheme"]), float(_d["deadzone"])])


func _write() -> void:
	var f := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_d, "\t"))
	f.close()
	DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH + ".tmp"),
			ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
