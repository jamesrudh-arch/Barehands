extends CanvasLayer

## B18.3 PART 0 (BUG 14): the START SEQUENCE. Everything is built from
## built-in nodes in code - no image files - and runs on Mobile/Metal.
## Flow: BLACK -> STUDIO CARD (the gold D'YOUNGS GAMES ring) -> CONTENT
## NOTICE -> TITLE CARD (LEVERAGE chromatic split over the live neon
## street) -> LOADING (bar + tip + stamp) -> MAIN MENU (PLAY / CONTINUE
## / SETTINGS / CREDITS, menu music, rain behind the buttons). Tap
## anywhere skips the remaining cards. Settings "skip_intro" jumps
## straight to the menu. Plays once per launch of the full game; Stage
## 0 and SafeBoot are separate scenes before this one.

const STUDIO_NAME := "D'YOUNGS GAMES"

enum Phase { BLACK, STUDIO, NOTICE, TITLE, LOADING, MENU, GONE }

var phase := Phase.BLACK
var _aborted := false
var _chimed := false
var _dim: ColorRect
var _skip: Control
var _ring: RingDraw
var _line: LineDraw
var _sweep: ColorRect
var _card_root: Control
var _title_root: Control
var _load_root: Control
var _menu_root: Control
var _credits_panel: Control
var _notice_root: Control


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The sequence plays on the REAL launch path only: Stage 0's LAUNCH
	# FULL GAME arms the flag. Suites, SafeBoot and re-loads boot the
	# game directly and must never sit behind a locked menu.
	if not bool(Settings.value("play_start_sequence")):
		phase = Phase.GONE
		queue_free()
		return
	Settings.set_value("play_start_sequence", false)
	_build_common()
	if bool(Settings.value("skip_intro")):
		_show_menu()
		return
	InputBus.locked = true
	Music.set_menu_mode(true)
	_run_sequence()


func _build_common() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 1)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_skip = Control.new()
	_skip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip.gui_input.connect(_on_skip_input)
	add_child(_skip)


func _run_sequence() -> void:
	await _black()
	if _aborted:
		return
	await _studio_card()
	if _aborted:
		return
	await _notice()
	if _aborted:
		return
	await _title_card()
	if _aborted:
		return
	await _loading()
	if _aborted:
		return
	_show_menu()


func _black() -> void:
	phase = Phase.BLACK
	_dim.color = Color(0, 0, 0, 1)
	await _wait(0.3)


# --- the studio card -----------------------------------------------------------


func _studio_card() -> void:
	phase = Phase.STUDIO
	_dim.color = Color(0, 0, 0, 1)
	_card_root = Control.new()
	_card_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_root)
	var gold := Color(0.788, 0.635, 0.294)  # #C9A24B
	# the gold ring that draws itself around a thinner inner ring
	_ring = RingDraw.new()
	_ring.progress = 0.0
	_ring.colour = gold
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	_ring.offset_left = -140
	_ring.offset_right = 140
	_ring.offset_top = -140
	_ring.offset_bottom = 140
	_card_root.add_child(_ring)
	# DY monogram at the centre, then the wide-tracked wordmark
	_card_label("DY", 84, Color(0.91, 0.85, 0.66), -56, -0.0, "serif")
	_card_label("D ' Y O U N G S", 44, Color(0.91, 0.85, 0.66), 150, 0.0, "serif")
	_card_label("G A M E S", 18, gold, 200, 0.0, "serif")
	_line = LineDraw.new()
	_line.progress = 0.0
	_line.colour = gold
	_line.set_anchors_preset(Control.PRESET_CENTER)
	_line.offset_top = 232
	_line.offset_bottom = 234
	_line.offset_left = -180
	_line.offset_right = 180
	_card_root.add_child(_line)
	# the light sweep across the wordmark, once
	_sweep = ColorRect.new()
	_sweep.color = Color(1, 0.97, 0.85, 0.0)
	_sweep.set_anchors_preset(Control.PRESET_CENTER)
	_sweep.offset_top = 150
	_sweep.offset_bottom = 200
	_card_root.add_child(_sweep)
	_swell(55.0, 3.0, 0.35)
	var t := 0.0
	while t < 3.2 and not _aborted:
		await get_tree().process_frame
		if _aborted:
			return
		t += _delta()
		_ring.progress = clampf(t / 1.6, 0.0, 1.0)
		_set_alpha("DY", clampf((t - 0.9) / 0.6, 0.0, 1.0))
		_set_alpha("D ' Y O U N G S", clampf((t - 1.5) / 0.6, 0.0, 1.0))
		_set_alpha("G A M E S", clampf((t - 1.7) / 0.6, 0.0, 1.0))
		_line.progress = clampf((t - 2.0) / 0.8, 0.0, 1.0)
		var sw := clampf((t - 2.2) / 0.7, 0.0, 1.0)
		_sweep.offset_left = -320 + sw * 420
		_sweep.offset_right = -280 + sw * 420
		_sweep.color.a = sin(sw * PI) * 0.2
		if t > 0.95 and not _chimed:
			_chimed = true
			Sound.play("metal_ring_1", -20.0, 0.55)
	if _aborted:
		return
	var f := 0.0
	while f < 0.4:
		await get_tree().process_frame
		if _aborted:
			return
		f += _delta()
		if _card_root:
			_card_root.modulate.a = 1.0 - f / 0.4
	_free_card(_card_root)
	_card_root = null


# --- the content notice --------------------------------------------------------


func _notice() -> void:
	phase = Phase.NOTICE
	_dim.color = Color(0, 0, 0, 1)
	_notice_root = Control.new()
	_notice_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notice_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notice_root)
	_notice_root.add_child(_full_label("MATURE THEMES 16+", 40,
			Color(0.95, 0.95, 0.95), 150, 200, 0))
	_notice_root.add_child(_full_label("Stylized violence, crime, strong language",
			18, Color(0.7, 0.7, 0.72), 210, 240, 0))
	await _wait(2.0)
	_free_card(_notice_root)
	_notice_root = null


# --- the title card ------------------------------------------------------------


func _title_card() -> void:
	phase = Phase.TITLE
	# the 3D key art (Part 0B): the extruded LEVERAGE + the cast rise
	# behind this card; the 2D wordmark only draws if the stage fell back
	var stage := get_tree().get_first_node_in_group("title_stage")
	var stage_3d := false
	if stage and stage.has_method("show_title"):
		stage.call("show_title")
		stage_3d = bool(stage.call("is_3d"))
	# the LIVE neon street is the skyline behind the wordmark: dim, not
	# black; the opening fly is already running under this layer
	_dim.color = Color(0.01, 0.01, 0.03, 0.62)
	_title_root = Control.new()
	_title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_root)
	# LEVERAGE: three offset copies - cyan left, magenta right, white
	# centre (the chromatic split), heavy condensed sans. In 3D mode the
	# TextMesh IS the title; only the 2D fallback draws these.
	if not stage_3d:
		for spec in [
			{"c": Color(0.2, 0.95, 1.0), "off": -5, "a": 0.92, "o": 0},
			{"c": Color(1.0, 0.2, 0.75), "off": 5, "a": 0.92, "o": 0},
			{"c": Color(0.97, 0.99, 1.0), "off": 0, "a": 1.0, "o": 4},
		]:
			var l := _full_label("LEVERAGE", 92, spec["c"], 240, 350, spec["off"],
					"sans", true)
			l.name = "TitleOff%s" % spec["off"]
			l.modulate.a = spec["a"]
			if int(spec["o"]) > 0:
				l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
				l.add_theme_constant_override("outline_size", 4)
			_title_root.add_child(l)
	_title_root.add_child(_full_label("Everyone has leverage on you.", 20,
			Color(0.85, 0.87, 0.95), 370, 400, 0))
	_title_root.add_child(_full_label("A %s production" % STUDIO_NAME, 14,
			Color(0.6, 0.6, 0.66), 640, 664, 0))
	_swell(110.0, 3.4, 0.3)
	Sound.play_v("bell_heavy", 2, -16.0, 0.62)
	Sound.play("sub_hit_1", -14.0, 0.55)
	Narrator.say_key("intro_0")
	var t := 0.0
	var said := 1
	var flick := 0.0
	while t < 4.2 and not _aborted:
		await get_tree().process_frame
		if _aborted:
			return
		t += _delta()
		flick += _delta()
		# the neon flicker: subtle, never blown out
		var a: float = 0.85 + 0.15 * sin(flick * 9.0) \
				* (1.0 if fmod(flick, 1.7) < 0.12 else 0.25)
		for c in _title_root.get_children():
			if c is Label and (c as Label).text == "LEVERAGE":
				(c as Label).modulate.a = a
		if said < 4 and t > 1.1 * said:
			Narrator.say_key("intro_%d" % said)
			said += 1
	_free_card(_title_root)
	_title_root = null


# --- loading -------------------------------------------------------------------


func _loading() -> void:
	phase = Phase.LOADING
	_dim.color = Color(0.01, 0.01, 0.03, 0.72)
	_load_root = Control.new()
	_load_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_load_root)
	_load_root.add_child(_full_label(
			"TIP: B opens doors and picks things up. X punches. The green light leads the way.",
			16, Color(0.7, 0.75, 0.8), 420, 452, 0))
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.1, 0.12, 0.16)
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_bg.offset_left = 500
	bar_bg.offset_right = 780
	bar_bg.offset_top = 460
	bar_bg.offset_bottom = 472
	_load_root.add_child(bar_bg)
	var bar := ColorRect.new()
	bar.color = Color(0.35, 0.95, 0.85)
	bar_bg.add_child(bar)
	_load_root.add_child(_full_label(BuildStamp.block(), 12,
			Color(0.45, 0.5, 0.55), 660, 680, 0))
	var t := 0.0
	while t < 1.4 and not _aborted:
		await get_tree().process_frame
		if _aborted:
			return
		t += _delta()
		bar.size.x = 276 * clampf(t / 1.3, 0.0, 1.0)
	_free_card(_load_root)
	_load_root = null


# --- the main menu ---------------------------------------------------------------


func _show_menu() -> void:
	phase = Phase.MENU
	_dim.color = Color(0.01, 0.01, 0.03, 0.45)
	# the 3D key art stays behind the menu (Part 0B.5): the cast + logo
	# hold the frame while the buttons sit over them
	var stage := get_tree().get_first_node_in_group("title_stage")
	if stage and stage.has_method("show_title") and not (stage as Node3D).visible:
		stage.call("show_title")
	Music.set_menu_mode(true)
	InputBus.locked = true
	if _skip:
		_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_root)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = 90
	col.offset_top = -40
	col.add_theme_constant_override("separation", 14)
	_menu_root.add_child(col)
	var head := _sys_label(STUDIO_NAME, 24, Color(0.35, 0.95, 0.85, 0.9),
			["Arial Black", "Arial", "sans-serif"], true)
	col.add_child(head)
	for spec in [
		{"text": "PLAY", "act": "_play"},
		{"text": "CONTINUE", "act": "_continue", "needs_save": true},
		{"text": "SETTINGS", "act": "_settings"},
		{"text": "CREDITS", "act": "_credits"},
	]:
		var b := Button.new()
		b.text = spec["text"]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(300, 74)
		b.add_theme_font_size_override("font_size", 22)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.04, 0.07, 0.82)
		sb.border_color = Color(0.35, 0.95, 0.85, 0.5)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", sb)
		var sbp := sb.duplicate()
		sbp.border_color = Color(0.35, 0.95, 0.85, 1.0)
		sbp.bg_color = Color(0.05, 0.09, 0.11, 0.92)
		b.add_theme_stylebox_override("hover", sbp)
		b.add_theme_stylebox_override("pressed", sbp)
		if spec.get("needs_save", false) and not SaveGame.has_save():
			b.disabled = true
			b.text = "CONTINUE (no save)"
		b.pressed.connect(Callable(self, spec["act"]))
		col.add_child(b)
	_menu_root.add_child(_full_label("A %s production" % STUDIO_NAME, 13,
			Color(0.55, 0.55, 0.6), 690, 712, 0))
	_menu_root.add_child(_full_label(BuildStamp.block(), 12,
			Color(0.4, 0.45, 0.5), 692, 714, 0))
	Sound.play("ui_confirm_0", -10.0)


func _play() -> void:
	_leave_menu()
	Narrator.stop()


func _continue() -> void:
	_leave_menu()
	if SaveGame.has_save():
		SaveGame.load_all()
		Sound.play("ui_confirm_0", -8.0)


func _settings() -> void:
	var ui := get_tree().get_first_node_in_group("settings_ui")
	if ui and ui.has_method("open"):
		ui.call("open")


func _credits() -> void:
	if _credits_panel:
		return
	_credits_panel = Control.new()
	_credits_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_panel.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override("separation", 10)
	_credits_panel.add_child(col)
	for line in [
		["D'YOUNGS GAMES", 26, Color(0.91, 0.85, 0.66)],
		["LEVERAGE", 18, Color(0.35, 0.95, 0.85)],
		["", 12, Color.WHITE],
		["Engine: Godot 4.7", 15, Color(0.75, 0.78, 0.82)],
		["Audio: Kenney (kenney.nl) - CC0", 15, Color(0.75, 0.78, 0.82)],
		["Music stems + synthesized bank: original (SYNTH_LICENSE.txt)", 15, Color(0.75, 0.78, 0.82)],
		["All other art, code and design: D'YOUNGS GAMES", 15, Color(0.75, 0.78, 0.82)],
	]:
		var l := _sys_label(line[0], line[1], line[2],
				["Arial", "sans-serif"], false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	var back := Button.new()
	back.text = "BACK"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(200, 56)
	back.pressed.connect(func():
		_credits_panel.queue_free()
		_credits_panel = null)
	col.add_child(back)
	add_child(_credits_panel)


func _leave_menu() -> void:
	if _menu_root:
		_menu_root.queue_free()
		_menu_root = null
	_dim.color = Color(0, 0, 0, 0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _skip:
		_skip.queue_free()
		_skip = null
	# hand the view back from the 3D title stage to the follow camera
	var stage := get_tree().get_first_node_in_group("title_stage")
	if stage and stage.has_method("hide_title"):
		stage.call("hide_title")
	InputBus.locked = false
	Music.set_menu_mode(false)
	# snap past the opening fly - the guide owns the first minute now
	var opening := get_tree().get_first_node_in_group("opening")
	if opening and opening.has_method("skip"):
		opening.call("skip")
	phase = Phase.GONE


# --- input + helpers --------------------------------------------------------------


func _on_skip_input(event: InputEvent) -> void:
	if phase in [Phase.BLACK, Phase.STUDIO, Phase.NOTICE, Phase.TITLE, Phase.LOADING]:
		if (event is InputEventScreenTouch and event.pressed) \
				or (event is InputEventMouseButton and event.pressed):
			_skip_all_cards()


func _skip_all_cards() -> void:
	if phase == Phase.MENU or phase == Phase.GONE:
		return
	_aborted = true
	Narrator.stop()
	_free_card(_card_root)
	_free_card(_notice_root)
	_free_card(_title_root)
	_free_card(_load_root)
	_card_root = null
	_notice_root = null
	_title_root = null
	_load_root = null
	_show_menu()


func _free_card(c: Control) -> void:
	if c and is_instance_valid(c):
		c.queue_free()


func _card_label(text: String, size: int, colour: Color, y: int, _x: int, family: String) -> Label:
	var l := _full_label(text, size, colour, y, y + int(size * 1.4), 0,
			family, false)
	l.modulate.a = 0.0
	if _card_root:
		_card_root.add_child(l)
	return l


func _set_alpha(text: String, a: float) -> void:
	if _card_root == null:
		return
	for c in _card_root.get_children():
		if c is Label and (c as Label).text == text:
			(c as Label).modulate.a = a


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _aborted:
		await get_tree().process_frame
		left -= _delta()


func _delta() -> float:
	return get_process_delta_time()


## A full-width label with centred text at a fixed y band - no anchor
## math to get wrong. x_shift nudges it sideways (the chromatic split).
func _full_label(text: String, size: int, colour: Color, y0: int, y1: int,
		x_shift := 0, family := "sans", bold := false) -> Label:
	var names: Array = ["Georgia", "Times New Roman", "serif"] if family == "serif" \
			else ["Arial Black", "Arial", "sans-serif"]
	var l := _sys_label(text, size, colour, names, bold)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = x_shift
	l.offset_right = x_shift
	l.offset_top = y0
	l.offset_bottom = y1
	return l


func _sys_label(text: String, size: int, colour: Color, names: Array, bold: bool) -> Label:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A low soft swell (a local synthesized one-shot; no audio files).
func _swell(freq: float, dur: float, vol: float) -> void:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := minf(1.0, t * 3.0) * exp(-t * 1.4) * vol
		var s: float = sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.3
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 16000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	var p := AudioStreamPlayer.new()
	p.stream = wav
	p.bus = "Music"
	p.volume_db = -6.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## The self-drawing gold ring of the studio card.
class RingDraw extends Control:
	var progress := 0.0
	var colour := Color(0.788, 0.635, 0.294)

	func _draw() -> void:
		var c := size * 0.5
		var r_out := minf(c.x, c.y) - 6.0
		draw_arc(c, r_out, -PI / 2.0, -PI / 2.0 + TAU, 96,
				colour * Color(1, 1, 1, 0.25), 2.0, true)
		if progress > 0.0:
			draw_arc(c, r_out, -PI / 2.0, -PI / 2.0 + TAU * progress, 96,
					colour, 3.0, true)
		draw_arc(c, r_out - 14.0, 0, TAU, 72,
				colour * Color(1, 1, 1, 0.35), 1.0, true)


## The thin gold line that draws beneath the wordmark.
class LineDraw extends Control:
	var progress := 0.0
	var colour := Color(0.788, 0.635, 0.294)

	func _draw() -> void:
		if progress <= 0.0:
			return
		draw_line(Vector2(0, size.y * 0.5),
				Vector2(size.x * progress, size.y * 0.5), colour, 1.5)
