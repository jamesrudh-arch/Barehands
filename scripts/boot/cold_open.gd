extends CanvasLayer

## THE COLD OPEN (S5.18): the intro where they actually CONVERSE.
## Marla's midnight call lands the story's grab in eight typed
## lines over the LIVE loft - rain on the skylight, the world
## running behind letterbox bars - then releases the player into
## M0 WAKE-UP CALL. Canon-only facts (tuning is the source of
## truth): the brother's five grand, split $3,500 family /
## $1,500 Corporation; Tony's boys at Marla's bar; the bag at
## the workbench. Plays once (intro_seen), honours skip_intro.

const LINES := [
	["RING", "INCOMING - MARLA", 0.9],
	["MARLA", "You pick up fast for a man who owes five grand.", 0.05],
	["YOU", "Marla. It's midnight.", 0.05],
	["MARLA", "It's raining on my bar and Tony's boys are still out front. They like the rain - nobody watches a street nobody walks.", 0.05],
	["YOU", "My brother's bill. I know the shape of it.", 0.05],
	["MARLA", "Then you know it came split. Thirty-five hundred to the family. Fifteen hundred to the Corporation - and their half doesn't wait for anybody's payday.", 0.05],
	["YOU", "He got himself into this.", 0.05],
	["MARLA", "And you've got hands that can get him out. The bag's at your workbench, the loft is quiet, and I need you at my bar before the week turns.", 0.05],
	["YOU", "Learn what the hands are for first.", 0.05],
	["END", "THE LOFT. THE BAG. THE STREET.", 1.6],
]

const RING_S := "metal_ring_0"   # the loft's phone

var _step := 0
var _typing := false
var _chars_shown := 0
var _type_t := 0.0
var _line_done := false
var _wait_t := 0.0
var _label: Label
var _speaker: Label
var _dim: ColorRect
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _advance_hint: Label
var _bar_h := 0.0


func _ready() -> void:
	name = "ColdOpen"
	layer = 30  # above the HUD (20), below nothing that matters
	Game.in_cinematic = true
	_build()
	Sound.play(RING_S, -4.0) if _has_clip(RING_S) else null
	_next_line()


func _has_clip(n: String) -> bool:
	return ResourceLoader.exists("res://assets/audio/%s.ogg" % n)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.12)  # the lens already grades
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	# THE BARS: slide in from off-frame (0 -> 12% of height)
	_bar_h = 0.0
	for bar_info in [["BarTop", 0.0], ["BarBot", 1.0]]:
		var bar := ColorRect.new()
		bar.name = str(bar_info[0])
		bar.color = Color(0, 0, 0)
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = float(bar_info[1])
		bar.anchor_bottom = float(bar_info[1])
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		if str(bar_info[0]) == "BarTop":
			_bar_top = bar
		else:
			_bar_bot = bar
	var f := _serif()
	_speaker = Label.new()
	_speaker.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speaker.position = Vector2(0, -150)
	_speaker.add_theme_font_override("font", f)
	_speaker.add_theme_font_size_override("font_size", 15)
	_speaker.add_theme_color_override("font_color",
			Color(1.0, 0.86, 0.5))
	_speaker.add_theme_constant_override("outline_size", 4)
	_speaker.add_theme_color_override("font_outline_color",
			Color(0, 0, 0, 0.85))
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_speaker)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.anchor_left = 0.07
	_label.anchor_right = 0.93
	_label.position = Vector2(0, -116)
	_label.add_theme_font_override("font", f)
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color",
			Color(0.97, 0.97, 1.0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color",
			Color(0, 0, 0, 0.9))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(
			DisplayServer.screen_get_size().x - 120, 80)
	add_child(_label)
	_advance_hint = Label.new()
	_advance_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_advance_hint.position = Vector2(0, -44)
	_advance_hint.add_theme_font_override("font", f)
	_advance_hint.add_theme_font_size_override("font_size", 12)
	_advance_hint.add_theme_color_override("font_color",
			Color(0.5, 0.55, 0.62))
	_advance_hint.text = "tap to continue"
	_advance_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_advance_hint)
	# the tap-catcher: full-screen, eats every touch (the HUD
	# never sees a finger while the call runs)
	var catcher := Control.new()
	catcher.name = "Catcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_tap)
	add_child(catcher)


func _serif() -> Font:
	return Fonts.serif()


func _process(delta: float) -> void:
	# the bars breathe in over ~1 s
	if _bar_h < 0.12:
		_bar_h = minf(_bar_h + delta * 0.16, 0.12)
		_layout_bars()
	if _typing:
		_type_t += delta
		var full := _full_text()
		while _chars_shown < full.length() \
				and _type_t > 0.032:
			_type_t -= 0.032
			_chars_shown += 1
		_label.text = full.substr(0, _chars_shown)
		if _chars_shown >= full.length():
			_typing = false
			_line_done = true
	elif _line_done and _step < LINES.size() - 1:
		_wait_t += delta
		if _wait_t > 2.8:   # the auto-advance floor
			_advance()
	elif _step == LINES.size() - 1:
		_wait_t += delta
		if _wait_t > 1.6:
			_end()


func _layout_bars() -> void:
	var sz := DisplayServer.screen_get_size()
	_bar_top.position = Vector2(0, 0)
	_bar_top.size = Vector2(sz.x, sz.y * _bar_h)
	_bar_bot.position = Vector2(0, sz.y * (1.0 - _bar_h))
	_bar_bot.size = Vector2(sz.x, sz.y * _bar_h)


func _full_text() -> String:
	# collapse the authored line-wraps; the label wraps itself
	var raw := str(LINES[_step][1])
	return " ".join(raw.split("\n\t\t"))


func _next_line() -> void:
	var kind := str(LINES[_step][0])
	_speaker.text = kind if kind in ["RING", "END"] else ""
	_label.text = ""
	_chars_shown = 0
	_type_t = 0.0
	_wait_t = 0.0
	_line_done = false
	if kind == "RING":
		_typing = false
		_label.text = _full_text()
		_line_done = true   # holds, tap advances
	else:
		_typing = true
	_advance_hint.visible = kind in ["RING"]


func _on_tap(ev: InputEvent) -> void:
	if ev is InputEventMouseButton \
			and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_input(ev: InputEvent) -> void:
	# keyboard/controller advance: any face key
	if ev.is_action_pressed("attack") \
			or ev.is_action_pressed("jump"):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if _typing:
		# finish the line instantly (the impatient-reader law)
		_label.text = _full_text()
		_chars_shown = _full_text().length()
		_typing = false
		_line_done = true
		_wait_t = 0.0
		return
	if _step >= LINES.size() - 1:
		_end()
		return
	_step += 1
	_next_line()


func _end() -> void:
	Game.in_cinematic = false
	WorldState.set_flag("intro_seen")
	queue_free()
