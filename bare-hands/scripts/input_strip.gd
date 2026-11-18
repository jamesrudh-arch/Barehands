class_name InputStrip
extends Control
## The noir input strip (combo pass PART 2): the last few face-button
## presses as small chips, and when a sequence lands, the combo's name
## lights up above them and fades. Lives bottom-centre of the HUD.

const CHIPS := 6
const CHIP_W := 34.0
const CHIP_H := 30.0
const GAP := 8.0

var _flash_name := ""
var _flash_t := 0.0
var _last_tokens: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -CHIPS * (CHIP_W + GAP) * 0.5
	offset_right = CHIPS * (CHIP_W + GAP) * 0.5
	offset_top = -168.0
	offset_bottom = -110.0
	ComboInput.matched.connect(_on_matched)


func _on_matched(combo_id: String) -> void:
	var def := ComboTable.by_id(combo_id)
	_flash_name = def.get("name", combo_id.to_upper())
	_flash_t = 1.4


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
	var toks := ComboInput.tokens()
	if toks != _last_tokens or _flash_t > 0.0:
		_last_tokens = toks.duplicate()
		queue_redraw()


func _chip_color(tok: String) -> Color:
	match tok:
		"A":
			return Color(1.0, 0.82, 0.6, 0.9)
		"B":
			return Color(1.0, 0.45, 0.35, 0.9)
		"X":
			return Color(0.45, 0.92, 1.0, 0.9)
		"Y":
			return Color(0.72, 1.0, 0.62, 0.9)
	return Color(1, 1, 1, 0.6)


func _draw() -> void:
	var toks: Array = _last_tokens
	var n := mini(toks.size(), CHIPS)
	var shown := toks.slice(maxi(0, toks.size() - CHIPS), toks.size())
	var total_w := shown.size() * (CHIP_W + GAP) - GAP
	var x := (size.x - total_w) * 0.5
	for i in shown.size():
		var tok: String = shown[i]
		var age := shown.size() - 1 - i  # 0 = newest
		var col := _chip_color(tok)
		col.a *= clampf(1.0 - float(age) * 0.13, 0.35, 1.0)
		var r := Rect2(x, size.y - CHIP_H - 6.0, CHIP_W, CHIP_H)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.04, 0.06, 0.55)
		sb.border_color = col
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		draw_style_box(sb, r)
		var font := get_theme_default_font()
		var ts: Vector2 = font.get_string_size(tok, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(font, r.position + (r.size - ts) * 0.5, tok,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.85))
		x += CHIP_W + GAP
	# the landed combo's name, lighting up then fading
	if _flash_t > 0.0 and _flash_name != "":
		var a := clampf(_flash_t / 1.4, 0.0, 1.0)
		var font := get_theme_default_font()
		var big := 22
		var ts: Vector2 = font.get_string_size(_flash_name, HORIZONTAL_ALIGNMENT_LEFT, -1, big)
		draw_string(font, Vector2((size.x - ts.x) * 0.5, 26), _flash_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(1.0, 0.72, 0.3, a))
		if _flash_t > 1.05:  # the first beat of the flash is hotter
			var glow := 1.0 - (1.4 - _flash_t) / 0.35
			draw_string(font, Vector2((size.x - ts.x) * 0.5 - 2.0, 26), _flash_name,
					HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(1, 1, 0.9, 0.4 * glow))
