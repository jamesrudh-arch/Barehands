class_name Shop
extends Area3D
## A street kiosk shop. Walk in, GRAB to browse; a noir panel lists items
## with effects and prices from the Wallet; buying applies the effect and
## writes the purchase into the Bullet Ledger. shop_id picks the stock:
## tailor (look), gear (stats), pawn (the gun counter placeholder).

const STOCK := {
	"tailor": [
		{"item": "Midnight coat", "desc": "deep blue wool", "price": 45, "apply": "coat_midnight"},
		{"item": "Oxblood coat", "desc": "dried-red leather", "price": 55, "apply": "coat_oxblood"},
		{"item": "Shadow coat", "desc": "back to black", "price": 40, "apply": "coat_shadow"},
	],
	"gear": [
		{"item": "Leather gloves", "desc": "+1 punch damage", "price": 80, "apply": "gloves"},
		{"item": "Track boots", "desc": "+8% run speed", "price": 60, "apply": "boots"},
		{"item": "Padded jacket", "desc": "-30% hit stun", "price": 70, "apply": "jacket"},
	],
	"pawn": [
		{"item": ".38 rounds", "desc": "priced per shot, always", "price": -1, "apply": ""},
		{"item": "Scoped iron", "desc": "arrives in a later series", "price": -1, "apply": ""},
	],
}
const TITLES := {
	"tailor": "STITCH & SHADOW  (tailor)",
	"gear": "IRON & LEATHER  (gear)",
	"pawn": "VELVET'S COUNTER  (pawn)",
}

@export var shop_id := "tailor"

var _panel: PanelContainer
var _inside := false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_inside = true
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_hint"):
			hud.show_hint("GRAB to browse", 3.0)


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_inside = false


func _physics_process(_delta: float) -> void:
	if _inside and InputBus.take_grab():
		_open()
	elif _panel == null:
		pass
	# the panel handles its own closing


func _open() -> void:
	if _panel:
		return
	InputBus.clear_queues()
	InputBus.locked = true
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -240.0
	_panel.offset_right = 240.0
	_panel.offset_top = -190.0
	_panel.offset_bottom = 160.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.032, 0.04, 0.96)
	sb.border_color = Color(0.92, 0.88, 0.78, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", sb)
	get_tree().current_scene.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)

	var title := Label.new()
	title.text = TITLES[shop_id]
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	col.add_child(title)

	var cash_line := Label.new()
	cash_line.name = "Cash"
	cash_line.text = "cash on hand   $%d" % Wallet.cash
	cash_line.add_theme_font_size_override("font_size", 14)
	cash_line.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	col.add_child(cash_line)

	for entry in STOCK[shop_id]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)
		var info := VBoxContainer.new()
		var name_l := Label.new()
		name_l.text = entry.item
		name_l.add_theme_font_size_override("font_size", 15)
		name_l.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
		info.add_child(name_l)
		var desc := Label.new()
		desc.text = entry.desc
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.6, 0.62, 0.6))
		info.add_child(desc)
		row.add_child(info)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var b := Button.new()
		if entry.price < 0:
			b.text = "info" if shop_id == "pawn" else "n/a"
			b.disabled = true
		else:
			b.text = "$%d" % entry.price
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(96, 44)
		b.add_theme_font_size_override("font_size", 15)
		var qsb := StyleBoxFlat.new()
		qsb.bg_color = Color(0.10, 0.10, 0.12, 0.9)
		qsb.border_color = Color(0.92, 0.88, 0.78, 0.4)
		qsb.set_border_width_all(1)
		qsb.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", qsb)
		var apply: String = entry.apply
		var price: int = entry.price
		var item_name: String = entry.item
		b.pressed.connect(func() -> void:
			_buy(item_name, apply, price))
		row.add_child(b)

	if shop_id == "pawn":
		var note := Label.new()
		note.text = "Every bullet is $%d, charged when it leaves the barrel.\nMore irons arrive in a later series." % Wallet.bullet_cost()
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(420, 0)
		col.add_child(note)

	var close := Button.new()
	close.text = "LEAVE"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(160, 48)
	close.add_theme_font_size_override("font_size", 16)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(1, 0.58, 0.13, 0.5)
	csb.set_corner_radius_all(6)
	close.add_theme_stylebox_override("normal", csb)
	close.pressed.connect(_close)
	col.add_child(close)
	Sound.play("door_open_0", -8.0)


func _buy(item_name: String, apply: String, price: int) -> void:
	if not Wallet.spend(price, item_name):
		Sound.play("ui_error_0", -6.0)
		return
	Sound.play("coins_0", -4.0)
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p and apply != "" and p.has_method("apply_purchase"):
		p.apply_purchase(apply)
	if _panel:
		var cash_line := _panel.get_node_or_null("Cash") as Label
		if cash_line:
			cash_line.text = "cash on hand   $%d" % Wallet.cash


func _close() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	InputBus.locked = false
	InputBus.clear_queues()
	Sound.play("door_close_0", -8.0)
