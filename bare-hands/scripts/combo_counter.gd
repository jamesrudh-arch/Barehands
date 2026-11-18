class_name ComboCounter
extends Control
## The on-screen combo counter (Stage A4): every landed hit bumps the count
## and shows the move's name; the count decays after ~1.2 s without a hit.
## Listens to the player's hit_landed signal. Top-centre, small, noir.

const DECAY := 1.2

var count := 0
var _since_hit := 0.0
var _last_move := ""
var _pop := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	position = Vector2(-60, 64)
	size = Vector2(120, 54)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_signal("hit_landed"):
		p.hit_landed.connect(_on_hit)


func _on_hit(kind: String, _total_damage: int) -> void:
	count += 1
	_since_hit = 0.0
	_last_move = kind.capitalize()
	_pop = 1.0
	if kind == "super":
		count = 0  # the super reads as its own moment
		queue_redraw()
		return
	if count == 8 and not Settings.hint_done("combo_8"):
		Settings.set_hint_done("combo_8")


func _process(delta: float) -> void:
	if count > 0:
		_since_hit += delta
		if _since_hit > DECAY:
			count = 0
			_last_move = ""
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	if count <= 0:
		return
	var c := size * 0.5
	var scale_f := 1.0 + 0.22 * _pop
	var font := get_theme_default_font()
	var big := int(30 * scale_f)
	var col := Color(1.0, 0.78, 0.35, clampf(0.55 + 0.1 * count, 0.0, 1.0))
	var text := "x%d" % count
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, big)
	draw_string(font, c - ts * 0.5 - Vector2(0, 10), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, big, col)
	if _last_move != "":
		var small := 13
		var s: Vector2 = font.get_string_size(_last_move, HORIZONTAL_ALIGNMENT_LEFT, -1, small)
		draw_string(font, c - s * 0.5 + Vector2(0, 14), _last_move,
				HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(0.85, 0.9, 0.95, 0.8))
