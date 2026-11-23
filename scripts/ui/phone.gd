extends CanvasLayer

## THE PHONE (rebuild step 11): the story's pocket terminal. PHONE
## opens it; the world dims (not pauses - the street keeps moving);
## B/PHONE closes. Three apps, all reading LIVE data: LEDGER (the
## cash, THE DEBT, the heat - the story's numbers), MESSAGES (the
## event log: mission beats, door breaks, deaths - what happened),
## CONTACTS (the cast the story has introduced so far).

const TABS := ["LEDGER", "MESSAGES", "CONTACTS"]

var _root: Control
var _tab: String = "LEDGER"
var _panel: PanelContainer
var _col: VBoxContainer


func _ready() -> void:
	name = "Phone"
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	# the phone slab: a tall panel right of centre (landscape)
	_panel = PanelContainer.new()
	_panel.name = "Slab"
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.custom_minimum_size = Vector2(420, 300)
	_panel.position = Vector2(-440, -150)
	_root.add_child(_panel)
	var head := HBoxContainer.new()
	head.name = "Tabs"
	_panel.add_child(head)
	for t in TABS:
		var b := Button.new()
		b.name = "Tab_" + t
		b.text = t
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(120, 40)
		b.pressed.connect(_set_tab.bind(t))
		head.add_child(b)
	_col = VBoxContainer.new()
	_col.name = "Body"
	_panel.add_child(_col)


func _process(_delta: float) -> void:
	# state-based edge (the pause menu lesson: single-frame synthetic
	# presses can fall between ticks)
	var p := Input.is_action_pressed("phone")
	if p and not _was_open and Game.state == Game.State.PLAY:
		open()
	elif not p and _was_open and _was_hold:
		close()
	_was_open = p
	if _root.visible:
		_fill()


var _was_open := false
var _was_hold := false


## The hero's action signal (the proven path - face_action fires
## for every mapped action; the direct poll below stays as the
## controller/keyboard second trigger).
func on_hero_action(action: String) -> void:
	if action != "phone" or Game.state != Game.State.PLAY:
		return
	if not _root.visible:
		open()
	else:
		close()


func open() -> void:
	_root.visible = true
	_was_hold = true
	_set_tab(_tab)
	Log.info("Phone: open (%s)" % _tab)


func close() -> void:
	_root.visible = false
	_was_hold = false


func _set_tab(t: String) -> void:
	_tab = t
	for b in _panel.get_node("Tabs").get_children():
		b.button_pressed = str(b.name).trim_prefix("Tab_") == t
	_fill()


func _fill() -> void:
	for c in _col.get_children():
		c.queue_free()
	match _tab:
		"LEDGER":
			_line("CASH  $%d" % int(float(WorldState.get_value(
					"stash_cash", 0.0))), Color(0.5, 1.0, 0.7))
			_line("THE DEBT  $%d" % int(float(WorldState.get_value(
					"debt", 0.0))), Color(1.0, 0.55, 0.3))
			_line("HEAT  %d" % int(float(WorldState.get_value(
					"heat", 0.0))), Color(1.0, 0.45, 0.2))
			_line("every landing is a checkpoint - dying costs $50",
					Color(0.45, 0.47, 0.58), 13)
		"MESSAGES":
			var log: Array = WorldState.event_log()
			if log.is_empty():
				_line("no messages - the street is quiet",
						Color(0.45, 0.47, 0.58))
			for e in log.slice(maxi(0, log.size() - 9), log.size()):
				_line("* %s" % str(e.get("kind", "?")),
						Color(0.75, 0.78, 0.9), 14)
		"CONTACTS":
			_line("THE BROTHER - 'get me out of this'",
					Color(0.95, 0.96, 0.99))
			_line("THE RAIN GLASS - the bar that fronts the errands",
					Color(0.95, 0.96, 0.99))
			_line("the streets have more faces as the story opens them",
					Color(0.45, 0.47, 0.58), 13)


func _line(text: String, col: Color, size := 16) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(400, 0)
	_col.add_child(l)
