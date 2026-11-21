class_name VisualDebug
extends CanvasLayer
## The VISUAL DEBUG panel (B15, Part A): live toggles and sliders for
## every visual system, so the owner can find a cause ON THE PHONE
## and paste the values back. Everything applies instantly through
## the Visual autoload; the overlay at the top shows the renderer
## name, resolution, orientation, FPS, draw calls and whether the
## touch controls loaded.
##
## XOGOT SAFE button: glow off, emission capped, simple tonemap,
## minimal particles - the Mobile-Metal safe preset (and the baked
## default on mobile). NIGHT restores the authored desktop look.
## COPY SETTINGS: every current value as selectable text.
## SCREENSHOT: saves a PNG next to the settings block.

const TONEMAPS := ["LINEAR", "REINHARD", "FILMIC", "ACES", "AGX"]

var _root: PanelContainer
var _overlay: Label
var _copy_popup: CanvasLayer


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_overlay()


# --- build -----------------------------------------------------------------


func _build() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.anchor_left = 0.5
	_root.anchor_right = 0.5
	_root.anchor_top = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left = -430.0
	_root.offset_right = 430.0
	_root.offset_top = -300.0
	_root.offset_bottom = 300.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.94)
	sb.border_color = Color(0.2, 0.75, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 580)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)

	_overlay = Label.new()
	_overlay.add_theme_font_size_override("font_size", 13)
	_overlay.add_theme_color_override("font_color", Color(0.7, 0.95, 0.9))
	_overlay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_overlay)

	_title(col, "PRESETS")
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	col.add_child(presets)
	_button(presets, "XOGOT SAFE", func():
		Visual.apply_profile(Visual.PROFILE_XOGOT_SAFE)
		_set_tonemap(3)
		_refresh_all())
	_button(presets, "NIGHT (desktop)", func():
		Visual.apply_profile(Visual.PROFILE_NIGHT)
		_set_tonemap(3)
		_refresh_all())
	_button(presets, "COPY SETTINGS", _copy_settings)
	_button(presets, "SCREENSHOT PNG", _screenshot)
	_button(presets, "CLOSE", func(): visible = false)

	_title(col, "GLOW / POST")
	var env := _env()
	_slider(col, "Glow on/off", "", 0, 1, 1, 1,
			func(v): Visual.post_on = v >= 0.5; Visual.apply_post())
	if env:
		_slider(col, "Glow intensity", "glow_intensity", 0.0, 2.0, 0.05,
				1.0, Callable())
		_slider(col, "Glow bloom", "glow_bloom", 0.0, 1.0, 0.01, 1.0, Callable())
		_slider(col, "Glow HDR threshold", "glow_hdr_threshold", 0.5, 4.0,
				0.05, 1.0, Callable())
	_button(col, "Tonemap: cycle (now %s)" % _tonemap_name(),
			func(): _set_tonemap((env.tonemap_mode + 1) % TONEMAPS.size()))

	_title(col, "EMISSION / LIGHT")
	_slider(col, "Sign+window emission x", "", 0.0, 1.5, 0.05, 1.0,
			func(v): Visual.emission_mult = v; Visual.apply_emission())
	_toggle(col, "Shadows", func(v): Visual.shadows_on = v; Visual.apply_shadows())

	_title(col, "RAIN / PARTICLES")
	_toggle(col, "Rain", func(v): Visual.rain_on = v; Visual.apply_rain())
	_slider(col, "Rain streak width", "", 0.003, 0.02, 0.001, 1000.0,
			func(v): Visual.rain_streak_width = v; Visual.apply_rain())
	_toggle(col, "Ground splash", func(v): Visual.splash_on = v; Visual.apply_rain())
	_toggle(col, "Decals (glow pools, stains)", func(v): Visual.decals_on = v; Visual.apply_decals())
	_toggle(col, "Enemy outline glow", func(v): Visual.outlines_on = v; Visual.apply_outlines())
	_toggle(col, "NPCs + crowd", func(v): Visual.npcs_on = v; Visual.apply_npcs())

	_title(col, "CAMERA")
	_slider(col, "Camera height", "", 1.0, 6.0, 0.1, 1.0,
			func(v): Visual.cam_height = v; Visual.apply_camera())
	_slider(col, "Camera distance", "", 3.0, 10.0, 0.1, 1.0,
			func(v): Visual.cam_distance = v; Visual.apply_camera())

	_refresh_all()


# --- helpers -----------------------------------------------------------------


func _env() -> Environment:
	var we := get_tree().get_first_node_in_group("world_env") as WorldEnvironment
	return we.environment if we else null


func _title(col: BoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
	col.add_child(l)


func _button(row: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	row.add_child(b)


func _toggle(col: BoxContainer, label: String, cb: Callable) -> void:
	var row := HBoxContainer.new()
	col.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(250, 0)
	l.add_theme_font_size_override("font_size", 14)
	row.add_child(l)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(90, 40)
	b.add_theme_font_size_override("font_size", 14)
	row.add_child(b)
	var state := [false]
	var refresh := func() -> void:
		b.text = "ON" if state[0] else "OFF"
		b.modulate = Color(1.35, 1.1, 0.75) if state[0] else Color.WHITE
	refresh.call()
	b.pressed.connect(func() -> void:
		state[0] = not state[0]
		refresh.call()
		cb.call(state[0]))
	_sync_rows.append(func() -> void:
		# reflect the live Visual state after a preset press
		pass)


var _sync_rows: Array = []


func _slider(col: BoxContainer, label: String, env_key: String,
		mn: float, mx: float, step: float, _mult: float,
		cb: Callable) -> void:
	var row := HBoxContainer.new()
	col.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(250, 0)
	l.add_theme_font_size_override("font_size", 14)
	row.add_child(l)
	var val := Label.new()
	val.custom_minimum_size = Vector2(70, 0)
	val.add_theme_font_size_override("font_size", 14)
	row.add_child(val)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = step
	sl.custom_minimum_size = Vector2(330, 40)
	sl.focus_mode = Control.FOCUS_NONE
	row.add_child(sl)
	var env := _env()
	if env_key != "" and env:
		sl.value = env.get(env_key)
	elif cb.is_valid():
		sl.value = _current_for(label)
	var fmt := "%.3f" if mx < 0.1 else "%.2f"
	val.text = fmt % sl.value
	sl.value_changed.connect(func(v: float) -> void:
		val.text = fmt % v
		if env_key != "" and env:
			env.set(env_key, v)
			if env_key.begins_with("glow"):
				env.glow_enabled = env.glow_intensity > 0.001
		if cb.is_valid():
			cb.call(v)
		_refresh_overlay())


func _current_for(label: String) -> float:
	match label:
		"Sign+window emission x": return Visual.emission_mult
		"Rain streak width": return Visual.rain_streak_width
		"Camera height": return Visual.cam_height
		"Camera distance": return Visual.cam_distance
	return 0.0


func _tonemap_name() -> String:
	var env := _env()
	return TONEMAPS[env.tonemap_mode] if env else "?"


func _set_tonemap(mode: int) -> void:
	var env := _env()
	if env:
		env.tonemap_mode = mode
		_refresh_all()


# --- the money buttons ---------------------------------------------------------


func _copy_settings() -> void:
	if _copy_popup:
		_copy_popup.queue_free()
	_copy_popup = CanvasLayer.new()
	_copy_popup.layer = 24
	add_child(_copy_popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_copy_popup.add_child(dim)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -430.0
	box.offset_right = 430.0
	box.offset_top = -240.0
	box.offset_bottom = 240.0
	_copy_popup.add_child(box)
	var col := VBoxContainer.new()
	box.add_child(col)
	var hint := Label.new()
	hint.text = "Select all, copy, paste it back to the agent:"
	hint.add_theme_font_size_override("font_size", 14)
	col.add_child(hint)
	var te := TextEdit.new()
	te.text = Visual.dump_settings()
	te.editable = false
	te.custom_minimum_size = Vector2(840, 400)
	te.add_theme_font_size_override("font_size", 13)
	col.add_child(te)
	var close := Button.new()
	close.text = "CLOSE"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): _copy_popup.queue_free())
	col.add_child(close)


func _screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	var fname := "screenshot_%d.png" % Time.get_unix_time_from_system()
	var path := "user://%s" % fname
	img.save_png(path)
	var abs := ProjectSettings.globalize_path(path)
	print("VISUAL screenshot: ", abs)
	if DisplayServer.get_name() != "headless":
		OS.alert("Saved: " + abs, "Screenshot")
	if _copy_popup == null or not is_instance_valid(_copy_popup):
		_copy_settings()
	# append the path to the settings block if it is open
	if _copy_popup and is_instance_valid(_copy_popup):
		for n in _copy_popup.find_children("*", "TextEdit", true, false):
			(n as TextEdit).text += "\nscreenshot: " + abs


func _refresh_all() -> void:
	_refresh_overlay()


func _refresh_overlay() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var env := _env()
	var hud := get_tree().get_first_node_in_group("hud")
	var buttons := 0
	if hud:
		for c in hud.get_children():
			if c is ActionButton and (c as ActionButton).visible:
				buttons += 1
	var info := Visual.dump_settings().split("\n")
	var shown: Array[String] = []
	for line in info:
		shown.append(line)
	shown.append("draw calls: %d" % Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	shown.append("visual: tonemap %s" % _tonemap_name())
	shown.append("touch loaded: %s" % ("YES (%d buttons)" % buttons
			if buttons > 0 else "NO - touch controls MISSING"))
	_overlay.text = "\n".join(shown)


func _process(_delta: float) -> void:
	if visible:
		_refresh_overlay()
