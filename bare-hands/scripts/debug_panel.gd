extends CanvasLayer
## Toggleable debug overlay: FPS, memory, node count, enemies, particles.
## Toggle with the small DBG button (top-left) or F3 on a keyboard.
## Everything is built in code so main.tscn stays declarative.

var _label: Label
var _tick := 0.0


func _ready() -> void:
	layer = 10
	var btn := Button.new()
	btn.text = "DBG"
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = Vector2(10, 10)
	btn.custom_minimum_size = Vector2(64, 34)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.9))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.05, 0.08, 0.35)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.pressed.connect(_toggle)
	add_child(btn)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(10, 50)
	panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.82)
	sb.border_color = Color(1, 0.58, 0.13, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.9, 0.95))
	panel.add_child(_label)

	# Batch 0 jumps: the live TUNING PANEL and the in-game TEST RUNNER
	var jumps := HBoxContainer.new()
	jumps.add_theme_constant_override("separation", 8)
	panel.add_child(jumps)
	var tune := Button.new()
	tune.text = "TUNING PANEL"
	tune.focus_mode = Control.FOCUS_NONE
	tune.pressed.connect(_toggle_tool.bind("TuningPanel"))
	jumps.add_child(tune)
	var tests := Button.new()
	tests.text = "TEST RUNNER"
	tests.focus_mode = Control.FOCUS_NONE
	tests.pressed.connect(_toggle_tool.bind("TestRunner"))
	jumps.add_child(tests)
	var style := Button.new()
	style.text = "STYLE WHEEL"
	style.focus_mode = Control.FOCUS_NONE
	style.pressed.connect(_open_style_wheel)
	jumps.add_child(style)
	# Batch 5: jump straight into the phone pressure loop
	var ring := Button.new()
	ring.text = "RING NOW"
	ring.focus_mode = Control.FOCUS_NONE
	ring.pressed.connect(_ring_now)
	jumps.add_child(ring)
	var clr := Button.new()
	clr.text = "CLEAR PHONE"
	clr.focus_mode = Control.FOCUS_NONE
	clr.pressed.connect(func(): Phone.reset_for_test())
	jumps.add_child(clr)
	# Batch 6: jump straight into the debt book's pressure
	var debt_b := Button.new()
	debt_b.text = "DEBT +500"
	debt_b.focus_mode = Control.FOCUS_NONE
	debt_b.pressed.connect(func():
		Ledger.debt["family"] += 500.0
		Ledger.changed.emit())
	jumps.add_child(debt_b)
	var day_b := Button.new()
	day_b.text = "DAY END"
	day_b.focus_mode = Control.FOCUS_NONE
	day_b.pressed.connect(func():
		while Ledger.beats_left > 0:
			Ledger.spend_beat("debug"))
	jumps.add_child(day_b)
	var def_b := Button.new()
	def_b.text = "DEFAULT NOW"
	def_b.focus_mode = Control.FOCUS_NONE
	def_b.pressed.connect(func(): Ledger.debug_default())
	jumps.add_child(def_b)


## Batch 5: a random friend calls, right now, whatever the hero is doing.
func _ring_now() -> void:
	var options := Trust.callers()
	if options.is_empty():
		return
	Phone.ring(options[randi() % options.size()],
			"demand" if randi() % 2 == 0 else "invitation")


## Batch 3: the debug menu jumps straight to the style wheel.
func _open_style_wheel() -> void:
	var tb := get_tree().get_first_node_in_group("hud_buttons")
	if tb and tb.has_method("_open_wheel"):
		tb.call("_open_wheel")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		_toggle()


func _toggle() -> void:
	var panel := get_node("Panel")
	panel.visible = not panel.visible
	if panel.visible:
		_refresh()


## Lazily create and toggle the debug tools (prompt 9F: the debug menu can
## jump to any system). Both are CanvasLayers built entirely in code.
func _toggle_tool(name: String) -> void:
	var tool := get_node_or_null("../" + name)
	if tool == null:
		if name == "TuningPanel":
			tool = TuningPanel.new()
			tool.name = "TuningPanel"
		else:
			tool = TestRunner.new()
			tool.name = "TestRunner"
		get_parent().add_child(tool)
	tool.toggle()


func _process(delta: float) -> void:
	if not get_node("Panel").visible:
		return
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		_refresh()


func _refresh() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var states := ""
	for e in enemies:
		states += "\n  %s %s hp=%d" % [e.name, Enemy.State.find_key(e.state), e.hp]
	var fps := Engine.get_frames_per_second()
	_label.text = "%d fps   %.1f ms" % [fps, 1000.0 / maxf(fps, 1)]
	_label.text += "\nmem static %.1f MB   orphans %d" % [
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)]
	_label.text += "\nnodes %d   objects %d   draws %d" % [
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	_label.text += "\nenemies %d%s" % [enemies.size(), states]
	_label.text += "\nparticles in flight %d   time_scale %.2f" % [Fx._bursts_alive, Engine.time_scale]
	_label.text += "\nlog: %s" % ProjectSettings.globalize_path("user://barehands.log")
