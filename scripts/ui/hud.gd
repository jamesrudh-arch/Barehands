extends CanvasLayer

## THE HUD (rebuild step 8): the play readouts, every one reading a
## LIVE system - the Leverage meter and Style Rank from Combat, the
## cash line from WorldState, the combo counter, the style name, the
## B-context verb on the diamond. Nothing decorative, nothing fake:
## there is no health bar yet because nothing damages the hero (the
## damage system lands with enemies; the HUD grows then).

const STYLE_ORDER := ["brawler", "kickboxing", "grappling", "drunken",
	"weapon"]

var _health: ProgressBar
var _meter: ProgressBar
var _rank_label: Label
var _cash: Label
var _combo: Label
var _ammo_label: Label = null
var _gun: Node = null
var _heat_pips: Array = []
var _style: Label
var _verb: Label
var _heat_line: Label
var _wheel: PanelContainer
var _wheel_buttons: Array = []
var _tick := 0


func _ready() -> void:
	name = "HUD"
	layer = 25
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# the health bar (above the meter - the thing you check first)
	_health = ProgressBar.new()
	_health.name = "HealthBar"
	_health.position = Vector2(24, 18)
	_health.size = Vector2(220, 10)
	_health.min_value = 0.0
	_health.max_value = 100.0
	_health.show_percentage = false
	_health.modulate = Color(0.9, 0.25, 0.3)
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_health)
	# top-left: the Leverage meter + rank (the fight's two currencies)
	_meter = ProgressBar.new()
	_meter.position = Vector2(24, 32)
	_meter.name = "LeverageMeter"
	_meter.position = Vector2(24, 20)
	_meter.size = Vector2(220, 14)
	_meter.min_value = 0.0
	_meter.max_value = 100.0
	_meter.show_percentage = false
	_meter.modulate = Color(1.0, 0.85, 0.3)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_meter)
	_rank_label = Label.new()
	_rank_label.name = "RankLabel"
	_rank_label.text = "RANK D"
	_rank_label.position = Vector2(24, 50)
	_rank_label.add_theme_font_size_override("font_size", 16)
	_rank_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_rank_label)
	# the HEAT pips (top-left under the rank; the phone LEDGER has
	# the number - this is the glance read)
	_heat_pips = []
	for i in 8:
		var pip := ColorRect.new()
		pip.name = "HeatPip%d" % i
		# centre-top: the banner owns top-left (probe-caught: the
		# mission objective's dark panel occluded the first pip row)
		pip.position = Vector2(594 + i * 13, 14)
		pip.size = Vector2(9, 14)
		pip.color = Color(0.95, 0.65, 0.25) if i < 2 \
				else (Color(0.95, 0.45, 0.2) if i < 5 \
				else Color(0.9, 0.2, 0.25))
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.visible = false
		root.add_child(pip)
		_heat_pips.append(pip)
	# top-right: the cash line + the combo counter
	_cash = Label.new()
	_cash.name = "CashLine"
	_cash.text = "$0"
	_cash.position = Vector2(-184, 20)
	_cash.anchor_left = 1.0
	_cash.anchor_right = 1.0
	_cash.offset_left = -120.0
	_cash.offset_right = -24.0
	_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cash.add_theme_font_size_override("font_size", 18)
	_cash.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	_cash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cash)
	_combo = Label.new()
	_combo.name = "ComboLine"
	_combo.text = ""
	_combo.anchor_left = 1.0
	_combo.anchor_right = 1.0
	_combo.offset_left = -120.0
	_combo.offset_right = -24.0
	_combo.offset_top = 44.0
	_combo.offset_bottom = 68.0
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo.add_theme_font_size_override("font_size", 15)
	_combo.add_theme_color_override("font_color", Color(0.95, 0.96, 0.99))
	_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_combo)
	# the ammo counter (top-right under the combo line; only when
	# the pistol is drawn)
	_ammo_label = Label.new()
	_ammo_label.name = "AmmoLine"
	_ammo_label.text = ""
	_ammo_label.anchor_left = 1.0
	_ammo_label.anchor_right = 1.0
	_ammo_label.offset_left = -120.0
	_ammo_label.offset_right = -24.0
	_ammo_label.offset_top = 68.0
	_ammo_label.offset_bottom = 92.0
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.add_theme_font_size_override("font_size", 18)
	_ammo_label.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.45))
	_ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ammo_label)
	# bottom-centre-left: the current style
	_style = Label.new()
	_style.name = "StyleLine"
	_style.text = "BRAWLER"
	_style.position = Vector2(24, 68)
	_style.add_theme_font_size_override("font_size", 13)
	_style.add_theme_color_override("font_color", Color(0.62, 0.66, 0.8))
	_style.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_style)
	# the B-context verb echo (what the diamond's B shows)
	_verb = Label.new()
	_verb.name = "VerbEcho"
	_verb.text = ""
	_verb.position = Vector2(24, 86)
	_verb.add_theme_font_size_override("font_size", 13)
	_verb.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	_verb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_verb)
	_heat_line = Label.new()
	_heat_line.name = "HeatLine"
	_heat_line.text = ""
	_heat_line.position = Vector2(24, 104)
	_heat_line.add_theme_font_size_override("font_size", 13)
	_heat_line.add_theme_color_override("font_color",
			Color(1.0, 0.45, 0.2))
	_heat_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_heat_line)
	_build_wheel(root)
	set_process(true)


## The style wheel: hold STYLE and the world slows (~30%); the radial
## picker lists the five; a tap swaps. Release closes.
func _build_wheel(root: Control) -> void:
	_wheel = PanelContainer.new()
	_wheel.name = "StyleWheel"
	_wheel.visible = false
	_wheel.set_anchors_preset(Control.PRESET_CENTER)
	_wheel.position = Vector2(-150, -110)
	_wheel.custom_minimum_size = Vector2(300, 220)
	root.add_child(_wheel)
	var col := VBoxContainer.new()
	col.name = "WheelList"
	_wheel.add_child(col)
	for id in STYLE_ORDER:
		var b := Button.new()
		b.name = "Style_" + id
		b.text = id.to_upper()
		b.custom_minimum_size = Vector2(260, 34)
		b.pressed.connect(_pick_style.bind(id))
		col.add_child(b)
		_wheel_buttons.append(b)


func _process(_delta: float) -> void:
	# the gun's ammo readout (hooked once - the gun rides the hero)
	if _gun == null:
		var hero := get_tree().get_first_node_in_group("player")
		if hero:
			_gun = hero.get_node_or_null("Gun")
			if _gun:
				_gun.ammo_changed.connect(_on_ammo)
				if _gun.drawn:
					_on_ammo(_gun.ammo, _gun.reserve)
	_tick += 1
	if _tick % 3 != 0:  # ~20 Hz: readouts do not need every frame
		return
	var hero0 := get_tree().get_first_node_in_group("player")
	if hero0 and is_instance_valid(hero0):
		_health.value = float(hero0.get("hp"))
	var combat := _combat()
	if combat:
		_meter.value = float(combat.get("meter"))
		var rank := int(combat.get("rank"))
		_rank_label.text = "RANK %s" % ["D", "C", "B", "A", "S"][
				clampi(rank, 0, 4)]
		_style.text = str(combat.get("style_id")).to_upper()
		var combo := int(combat.get("combo_count"))
		_combo.text = "%d HIT" % combo if combo > 0 else ""
	# the pools at a glance: dirty always, clean when it exists
	var clean := int(float(WorldState.get_value("clean_cash", 0.0)))
	_cash.text = "DIRTY $%d" % int(float(WorldState.get_value(
			"stash_cash", 0.0)))
	if clean > 0:
		_cash.text += "  ·  CLEAN $%d" % clean
	var hero := get_tree().get_first_node_in_group("player")
	var verb := ""
	if hero and is_instance_valid(hero) and hero.has_method("context_verb"):
		verb = str(hero.call("context_verb"))
	_verb.text = "B: %s" % verb if verb != "" else ""
	# the heat line + pip row: only when the street is watching
	# (the HUD already had the text line - the pips join it; one
	# var, one scope - the parse law)
	var heat := float(WorldState.get_value("heat", 0.0))
	_heat_line.visible = heat > 1.0
	_heat_line.text = "HEAT %d" % int(heat)
	var n_pips := clampi(ceili(heat), 0, 8)
	for i in 8:
		_heat_pips[i].visible = i < n_pips
	# feed the touch UI's B label too (the button is the primary read)
	var ui := get_node_or_null("/root/Game/TouchUI")
	if ui and ui.has_method("set_context_verb"):
		ui.call("set_context_verb", verb)
	# the wheel: hold to slow the world, tap to swap
	var holding := Input.is_action_pressed("style")
	if holding != _wheel.visible:
		_wheel.visible = holding
		Engine.time_scale = 0.7 if holding else 1.0


func _pick_style(id: String) -> void:
	var combat := _combat()
	if combat and combat.has_method("set_style"):
		combat.call("set_style", id)
		Log.info("HUD: style wheel -> %s" % id)


func _combat() -> Node:
	var hero := get_tree().get_first_node_in_group("player")
	if hero == null or not is_instance_valid(hero):
		return null
	return hero.get_node_or_null("Combat")


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # never leave the world slowed

func _on_ammo(in_clip: int, reserve: int) -> void:
	if _ammo_label == null:
		return
	if in_clip < 0:
		_ammo_label.text = ""
	else:
		_ammo_label.text = "PISTOL %d / %d" % [in_clip, reserve]
