extends CanvasLayer
const CLS_MorningReport := preload("res://scripts/morning_report.gd")
## The morning report (bible 15, batch 9): when a day closes - beats
## burnt out or slept away at the safehouse - one card says what the
## city did overnight. Interest, missed payments, who texted, who
## drifted, what cooled, what the street forgot. Tap anywhere to
## dismiss; it also fades on its own so a natural day-turn never
## traps the player in a menu.

const LIFE_S := 7.0

var _card: PanelContainer
var _timer: Timer


func _ready() -> void:
	layer = 40
	add_to_group("morning_report")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


static func show_report(day: int, lines: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node := tree.get_first_node_in_group("morning_report") as CLS_MorningReport
	if node == null:
		node = CLS_MorningReport.new()
		tree.root.add_child(node)
	node._present(day, lines)


func _present(day: int, lines: Array) -> void:
	for c in _card.get_children():
		c.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_card.add_child(col)
	var title := Label.new()
	title.text = "DAY %d" % day
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	col.add_child(title)
	if lines.is_empty():
		var quiet := Label.new()
		quiet.text = "the city slept. nothing moved."
		quiet.add_theme_font_size_override("font_size", 14)
		quiet.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
		col.add_child(quiet)
	for l in lines:
		var lab := Label.new()
		lab.text = str(l)
		lab.add_theme_font_size_override("font_size", 14)
		lab.add_theme_color_override("font_color", Color(0.72, 0.76, 0.8))
		col.add_child(lab)
	var hint := Label.new()
	hint.text = "tap to go on"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.4, 0.42, 0.46))
	col.add_child(hint)
	_card.visible = true
	_card.modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_card, "modulate:a", 1.0, 0.25)
	_timer.start(LIFE_S)
	Sound.play("ui_confirm_0", -10.0)


func dismiss() -> void:
	if not _card.visible:
		return
	_timer.stop()
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_card, "modulate:a", 0.0, 0.2)
	await tw.finished
	_card.visible = false


func _build() -> void:
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.position = Vector2(640 - 260, 40)
	_card.custom_minimum_size = Vector2(520, 0)
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			dismiss())
	add_child(_card)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.025, 0.035, 0.96)
	sb.border_color = Color(0.85, 0.75, 0.3, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_card.add_theme_stylebox_override("panel", sb)

	_timer = Timer.new()
	_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_timer.timeout.connect(func():
		var tw := create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(_card, "modulate:a", 0.0, 0.6)
		await tw.finished
		if _timer.is_stopped():
			_card.visible = false)
	add_child(_timer)
