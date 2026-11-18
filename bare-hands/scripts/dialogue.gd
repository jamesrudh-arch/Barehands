extends CanvasLayer
## The noir dialogue system. Bottom-of-screen panel: a colour portrait block
## with the speaker's initial, the name, text typed out character by
## character, a TAP hint. Any tap finishes the line, the next tap moves on.
## Gameplay input is locked while it runs. Every line emits a voice hook
## (signal + a Voice-bus player that plays assets/voice/<id>_<n>.wav when
## the recording exists - until then the hook is clean and empty).

signal line_started(speaker: String, voice_id: String, index: int)
signal finished()

var _panel: PanelContainer
var _portrait: PanelContainer
var _name: Label
var _text: Label
var _hint: Label
var _queue: Array = []
var _line := 0
var _speaker := ""
var _voice_id := ""
var _shown := 0.0
var _full_text := ""
var _active := false
var _voice := AudioStreamPlayer.new()


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_voice.bus = "Voice"
	add_child(_voice)
	_build()
	visible = false


func is_active() -> bool:
	return _active


## Queue lines: [{speaker, color, voice_id, text}, ...]
func run(lines: Array) -> void:
	if lines.is_empty():
		return
	_queue = lines.duplicate()
	_line = 0
	_active = true
	InputBus.locked = true
	visible = true
	_show_line()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.06
	_panel.anchor_right = 0.94
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -168.0
	_panel.offset_bottom = -36.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.022, 0.03, 0.95)
	sb.border_color = Color(0.85, 0.75, 0.55, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_panel.add_child(row)

	_portrait = PanelContainer.new()
	_portrait.custom_minimum_size = Vector2(84, 84)
	var psb := StyleBoxFlat.new()
	psb.set_corner_radius_all(10)
	psb.content_margin_left = 10.0
	psb.content_margin_right = 10.0
	psb.content_margin_top = 22.0
	psb.content_margin_bottom = 22.0
	_portrait.add_theme_stylebox_override("panel", psb)
	row.add_child(_portrait)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 17)
	_name.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	col.add_child(_name)

	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_color_override("font_color", Color(0.9, 0.89, 0.85))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 52)
	col.add_child(_text)

	_hint = Label.new()
	_hint.text = "tap to continue"
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55, 0.8))
	col.add_child(_hint)


func _process(delta: float) -> void:
	if not _active:
		return
	if _shown < _full_text.length():
		_shown = minf(_shown + delta * 42.0, _full_text.length())  # ~42 chars/s
		_text.text = _full_text.substr(0, roundi(_shown))


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton \
			or (event is InputEventKey and event.pressed):
		_advance()


func _advance() -> void:
	if _shown < _full_text.length():
		_shown = _full_text.length()  # finish typing first
		_text.text = _full_text
		return
	_line += 1
	if _line >= _queue.size():
		_close()
	else:
		_show_line()


func _show_line() -> void:
	var entry: Dictionary = _queue[_line]
	_speaker = entry.speaker
	_voice_id = entry.get("voice_id", _speaker.to_lower())
	_full_text = entry.text
	_shown = 0.0
	_text.text = ""
	var color: Color = entry.get("color", Color(0.8, 0.8, 0.8))
	_name.text = _speaker
	_name.add_theme_color_override("font_color", color)
	var psb: StyleBoxFlat = _portrait.get_theme_stylebox("panel").duplicate()
	psb.bg_color = color.darkened(0.55)
	_portrait.add_theme_stylebox_override("panel", psb)
	for c in _portrait.get_children():
		c.queue_free()
	var initial := Label.new()
	initial.text = _speaker.substr(0, 1)
	initial.add_theme_font_size_override("font_size", 40)
	initial.add_theme_color_override("font_color", color)
	_portrait.add_child(initial)
	_play_voice()
	line_started.emit(_speaker, _voice_id, _line)
	Music.duck(-7.0, 1.0)


## Voice hook: plays assets/voice/<voice_id>_<n>.wav if the recording exists.
func _play_voice() -> void:
	var path := "res://assets/voice/%s_%02d.wav" % [_voice_id, _line + 1]
	if ResourceLoader.exists(path):
		_voice.stream = load(path)
		_voice.play()
	else:
		_voice.stream = null  # the hook stays clean until recordings arrive


func _close() -> void:
	_active = false
	visible = false
	InputBus.locked = false
	InputBus.clear_queues()
	finished.emit()
