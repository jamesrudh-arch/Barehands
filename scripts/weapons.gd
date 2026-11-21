extends Node

## B18.3 PART 6D: the WEAPONS layer. One equipped improvised weapon
## (pipe, bat, bottle, plank, chair leg) riding on the player's
## existing pipe move set: every landed hit costs one durability, and
## at zero the weapon breaks with a sound and a message. The HUD chip
## (above the attack cluster) shows the weapon and its remaining life.
## Cash, health, keys and the burner phone are ITEMS - the pickups
## apply them directly, they never come in here.

const WEAPONS := {
	"pipe": {"name": "LEAD PIPE", "durability": 12},
	"bat": {"name": "BASEBALL BAT", "durability": 10},
	"bottle": {"name": "BOTTLE", "durability": 3},
	"plank": {"name": "WOOD PLANK", "durability": 6},
	"chair_leg": {"name": "CHAIR LEG", "durability": 6},
}

var equipped := ""  # weapon id, "" = bare hands
var durability := 0

var _layer: CanvasLayer
var _chip: PanelContainer
var _name_l: Label
var _bar: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Fx.hit_landed.connect(_on_hit)
	_build_chip()


func equip(id: String) -> void:
	if not WEAPONS.has(id):
		return
	equipped = id
	durability = int(WEAPONS[id]["durability"])
	_refresh()
	Sound.play("latch_0", -6.0)
	Sound.play("metal_click_0", -9.0)


func unequip(broke := false) -> void:
	if equipped == "":
		return
	var was: String = str(WEAPONS[equipped]["name"])
	equipped = ""
	durability = 0
	if broke:
		Sound.play("wood_heavy_0", -4.0, 0.8)
		Sound.play("glass_med_0", -10.0)
		var hud := get_tree().get_first_node_in_group("hud_buttons")
		if hud and hud.has_method("show_hint"):
			hud.show_hint("%s broke - bare hands again" % was, 2.6)
	_refresh()


func is_armed() -> bool:
	return equipped != ""


func weapon_name() -> String:
	return str(WEAPONS.get(equipped, {}).get("name", ""))


func frac() -> float:
	if equipped == "":
		return 0.0
	return clampf(float(durability) / float(WEAPONS[equipped]["durability"]), 0.0, 1.0)


## Every landed hit that is not the hero TAKING one costs durability.
func _on_hit(kind: String, _pos: Vector3) -> void:
	if equipped == "" or kind == "player_hit":
		return
	durability -= 1
	if durability <= 0:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("unequip_weapon"):
			player.call("unequip_weapon")
		unequip(true)
	else:
		_refresh()


func _build_chip() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_chip = PanelContainer.new()
	_chip.name = "WeaponChip"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.05, 0.85)
	sb.border_color = Color(1.0, 0.75, 0.3, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	_chip.add_theme_stylebox_override("panel", sb)
	_chip.anchor_left = 1.0
	_chip.anchor_right = 1.0
	_chip.anchor_top = 1.0
	_chip.anchor_bottom = 1.0
	# sits above the attack cluster, clear of the cash HUD and meter
	_chip.offset_left = -330.0
	_chip.offset_right = -160.0
	_chip.offset_top = -682.0
	_chip.offset_bottom = -640.0
	_chip.visible = false
	_layer.add_child(_chip)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_child(col)
	_name_l = Label.new()
	_name_l.add_theme_font_size_override("font_size", 14)
	_name_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_name_l)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.14)
	bg.custom_minimum_size = Vector2(140, 6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bg)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.72, 0.25)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_bar)


func _refresh() -> void:
	if _chip == null:
		return
	_chip.visible = equipped != ""
	if equipped == "":
		return
	_name_l.text = weapon_name()
	_bar.size.x = 140.0 * frac()
	_bar.color = Color(1.0, 0.72, 0.25) if frac() > 0.3 else Color(1.0, 0.35, 0.25)
