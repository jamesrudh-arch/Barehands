class_name MoveListUI
extends CanvasLayer
## The MOVES screen (combo pass PART 3), opened from the pause menu or the
## trainer. Generated from ComboTable + the base single presses: locked
## combos are greyed with "Unlocks at level N"; unlocked ones show their
## sequence, description and a PRACTISE button that stages the training
## dummy in front of the player and demos the sequence on the input strip.

var _panel: PanelContainer


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func open() -> void:
	_refresh()
	visible = true


func _close() -> void:
	visible = false
	var pause := get_tree().get_first_node_in_group("pause") as PauseMenu
	if pause:
		pause.show_menu()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -260.0
	_panel.offset_right = 260.0
	_panel.offset_top = -200.0
	_panel.offset_bottom = 200.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.95)
	sb.border_color = Color(1, 0.58, 0.13, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)


func _refresh() -> void:
	for c in _panel.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)

	_section(col, "SINGLE PRESSES - ALWAYS YOURS")
	_row(col, {"name": "Jab, Cross, Hook", "seq": ["tap PUNCH x3"], "desc":
			"The light chain. Face buttons: A, A, A.", "level": 1})
	_row(col, {"name": "Heavy hook", "seq": ["hold PUNCH"], "desc":
			"Face buttons: B. Breaks guards.", "level": 1})
	_row(col, {"name": "Kick", "seq": ["X"], "desc":
			"A mid-range poke; pops staggered enemies up.", "level": 1})
	_row(col, {"name": "Grab, knee, throw", "seq": ["Y"], "desc":
			"Seize, hold, dispose. Face buttons: Y (again to throw).", "level": 1})
	_row(col, {"name": "Dodge / Block / Parry", "seq": ["DODGE"], "desc":
			"Evade with the stick; hold to guard; time it to parry.", "level": 1})

	_section(col, "COMBOS - BARE FISTS")
	for def in ComboTable.ALL:
		if not def.get("pipe", false):
			_row(col, def)

	_section(col, "COMBOS - WITH THE PIPE")
	for def in ComboTable.ALL:
		if def.get("pipe", false):
			_row(col, def)

	var done := Button.new()
	done.text = "DONE"
	done.focus_mode = Control.FOCUS_NONE
	done.custom_minimum_size = Vector2(200, 50)
	done.add_theme_font_size_override("font_size", 17)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(1, 0.58, 0.13, 0.55)
	dsb.set_corner_radius_all(8)
	done.add_theme_stylebox_override("normal", dsb)
	done.pressed.connect(_close)
	col.add_child(done)


func _section(col: BoxContainer, title: String) -> void:
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
	col.add_child(t)


func _row(col: BoxContainer, def: Dictionary) -> void:
	var unlocked := int(def.get("level", 1)) <= Progression.level
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)

	var name_l := Label.new()
	name_l.text = "  " + str(def.get("name", "?"))
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.custom_minimum_size = Vector2(150, 0)
	name_l.add_theme_color_override("font_color",
			Color(0.95, 0.9, 0.8, 0.95) if unlocked else Color(0.45, 0.47, 0.5, 0.8))
	row.add_child(name_l)

	var seq: Array = def.get("seq", [])
	var seq_text := " > ".join(seq.map(func(t: String) -> String: return t.to_upper()))
	var how := Label.new()
	how.text = seq_text
	how.add_theme_font_size_override("font_size", 13)
	how.custom_minimum_size = Vector2(130, 0)
	how.add_theme_color_override("font_color",
			Color(0.55, 0.95, 1.0, 0.9) if unlocked else Color(0.4, 0.45, 0.5, 0.7))
	row.add_child(how)

	if not unlocked:
		var lock := Label.new()
		lock.text = "Unlocks at level %d" % int(def.get("level", 2))
		lock.add_theme_font_size_override("font_size", 13)
		lock.add_theme_color_override("font_color", Color(0.65, 0.55, 0.35, 0.85))
		row.add_child(lock)
	elif def.has("id"):
		var practise := Button.new()
		practise.text = "PRACTISE"
		practise.focus_mode = Control.FOCUS_NONE
		practise.custom_minimum_size = Vector2(110, 34)
		practise.add_theme_font_size_override("font_size", 12)
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.08, 0.09, 0.12, 0.8)
		psb.border_color = Color(1, 0.58, 0.13, 0.35)
		psb.set_border_width_all(1)
		psb.set_corner_radius_all(8)
		practise.add_theme_stylebox_override("normal", psb)
		var id: String = def.get("id", "")
		practise.pressed.connect(func() -> void: _practise(id))
		row.add_child(practise)

	var desc := Label.new()
	desc.text = "      " + str(def.get("desc", ""))
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color",
			Color(0.7, 0.8, 0.85, 0.75) if unlocked else Color(0.5, 0.52, 0.55, 0.6))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(460, 0)
	col.add_child(desc)


## PRACTISE: stage the dummy in front of the player, close the menus, and
## demo the sequence on the input strip.
func _practise(id: String) -> void:
	var def := ComboTable.by_id(id)
	if def.is_empty():
		return
	visible = false
	var pause := get_tree().get_first_node_in_group("pause") as PauseMenu
	if pause:
		pause.hide_menu()
	get_tree().paused = false
	var player := get_tree().get_first_node_in_group("player") as Player
	var dummy := get_tree().root.find_child("Dummy", true, false) as Enemy
	if player and dummy:
		dummy.set("kind", 0)
		dummy.state = Enemy.State.IDLE
		dummy.hp = 99
		var fwd := -player._body.global_transform.basis.z
		dummy.global_position = player.global_position + fwd * 1.4 + Vector3(0, 0.02, 0)
		dummy.velocity = Vector3.ZERO
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint("%s: %s" % [def["name"], " > ".join(
				(def["seq"] as Array).map(func(t: String) -> String: return t.to_upper()))], 3.0)
