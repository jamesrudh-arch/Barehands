extends Area3D
## The safehouse door on the north face. GRAB to open the panel: SAVE writes
## everything (wallet, heat, gear, look, position, style) to user://save.json;
## LOAD restores it. A save also records the state the city will remember in
## the next phase.

var _panel: PanelContainer
var _inside := false


func _ready() -> void:
	add_to_group("safehouse")
	# B18 6C: the door facts the DEVICE REPORT + guide read
	add_to_group("door_prompt")
	set_meta("door_name", "SAFEHOUSE DOOR (street)")
	set_meta("door_state", "save terminal")
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_inside = true
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_hint"):
			hud.show_hint("GRAB at the safehouse door", 3.0)


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_inside = false


## The player asks: is this door worth a GRAB? (single GRAB consumer)
func try_use(_player: Node3D) -> bool:
	if _inside and _panel == null:
		_open()
		return true
	return false


func _open() -> void:
	InputBus.clear_queues()
	InputBus.locked = true
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -200.0
	_panel.offset_right = 200.0
	_panel.offset_top = -150.0
	_panel.offset_bottom = 120.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.032, 0.04, 0.96)
	sb.border_color = Color(0.45, 0.75, 0.9, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", sb)
	get_tree().current_scene.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	var title := Label.new()
	title.text = "SAFEHOUSE"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	col.add_child(title)

	var status := Label.new()
	status.name = "Status"
	status.text = SaveGame.describe()
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	col.add_child(status)

	var choices: Array = [["SAVE", _save], ["LOAD", _load],
			["SLEEP - end the day", _sleep],
			["GO INSIDE - your room", _go_inside]]
	for choice in choices:
		var b := Button.new()
		b.text = choice[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(340, 52)
		b.add_theme_font_size_override("font_size", 16)
		var qsb := StyleBoxFlat.new()
		qsb.bg_color = Color(0.10, 0.10, 0.12, 0.9)
		qsb.border_color = Color(0.45, 0.75, 0.9, 0.4)
		qsb.set_border_width_all(1)
		qsb.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", qsb)
		b.pressed.connect((choice[1] as Callable).bind())
		col.add_child(b)

	var close := Button.new()
	close.text = "LEAVE"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(340, 48)
	close.add_theme_font_size_override("font_size", 15)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(1, 0.58, 0.13, 0.5)
	csb.set_corner_radius_all(6)
	close.add_theme_stylebox_override("normal", csb)
	close.pressed.connect(_close)
	col.add_child(close)
	Sound.play("creak_0", -8.0)


## Sleep: forfeit the day's leftover beats, close the books, save,
## and wake to the morning report (the world sim owns the night).
func _sleep() -> void:
	_close()
	WorldSim.sleep()


## B18 6C: the door works from BOTH sides - step into the apartment
## (the starting room) through the same fade every interior uses.
func _go_inside() -> void:
	_close()
	var ap: Node = null
	for n in get_tree().get_nodes_in_group("door_prompt"):
		if str(n.name).begins_with("Apartment"):
			ap = n
			break
	if ap == null or not ap.has_method("arrive_from_street"):
		return
	InputBus.locked = true
	var blocks := get_tree().root.get_node_or_null("/root/Blocks")
	if blocks:
		await blocks.call("fade_out")
	ap.call("arrive_from_street")
	if blocks:
		await blocks.call("fade_in")
	InputBus.locked = false


func _save() -> void:
	SaveGame.save_all()
	_refresh_status()
	Sound.play("ui_confirm_0", -6.0)


func _load() -> void:
	if SaveGame.load_all():
		_refresh_status()
		Sound.play("ui_confirm_0", -6.0)
	else:
		Sound.play("ui_error_0", -6.0)


func _refresh_status() -> void:
	var s := _panel.get_node_or_null("Status") as Label
	if s:
		s.text = SaveGame.describe()


func _close() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	InputBus.locked = false
	InputBus.clear_queues()
	Sound.play("door_close_0", -8.0)
