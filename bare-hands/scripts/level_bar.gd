class_name LevelBar
extends Control
## The level bar (combo pass PART 3): "LV n" + a thin fill strip, top-left
## under the debug panel. On a level-up: a centre banner with the level,
## each newly unlocked move's name, and its button sequence demoed chip by
## chip on the input strip; a sting and a haptic sell the moment.

var _bar_fill := 0.0
var _banner_t := 0.0
var _banner_level := 0
var _banner_moves: Array = []  # [{name, seq}]
var _demo_queue: Array = []
var _demo_i := 0
var _demo_t := 0.0


func _ready() -> void:
	add_to_group("level_bar")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 96.0
	offset_top = 48.0
	offset_right = 260.0
	offset_bottom = 74.0
	var pending: Array = Progression.take_pending()
	if not pending.is_empty():
		level_up(Progression.level, pending)


## Called by Progression on a level-up.
func level_up(new_level: int, unlocked_ids: Array) -> void:
	_banner_level = new_level
	_banner_moves = []
	for id in unlocked_ids:
		var def := ComboTable.by_id(id)
		if not def.is_empty():
			_banner_moves.append({"name": def["name"], "seq": def["seq"]})
	_banner_t = 3.2
	Sound.play("bell_heavy_0", -2.0, 1.15)
	Sound.play("ui_confirm_0", -6.0, 1.2)
	Haptics.fire("parry")
	# demo each new move's sequence on the input strip
	for m in _banner_moves:
		_demo_queue.append(m["seq"])
	queue_redraw()


func _process(delta: float) -> void:
	var frac := clampf(Progression.xp / Progression.xp_needed(Progression.level), 0.0, 1.0)
	if absf(frac - _bar_fill) > 0.005 or _banner_t > 0.0:
		_bar_fill = frac
		queue_redraw()
	if _banner_t > 0.0:
		_banner_t = maxf(0.0, _banner_t - delta)
	# the sequence demo: flash chips one by one on the input strip
	if _demo_queue.is_empty():
		return
	_demo_t += delta
	if _demo_t >= 0.42:
		_demo_t = 0.0
		var seq: Array = _demo_queue[0]
		_demo_i += 1
		if _demo_i >= seq.size():
			_demo_queue.pop_front()
			_demo_i = 0
			_demo_t = -0.5  # a beat between moves
		flash_chip(seq)


func flash_chip(seq: Array) -> void:
	if seq.is_empty() or _demo_i >= seq.size():
		return
	var strip := get_tree().get_first_node_in_group("input_strip")
	if strip and strip.has_method("demo_flash"):
		strip.demo_flash(str(seq[_demo_i]))


func _draw() -> void:
	var font := get_theme_default_font()
	# the label
	draw_string(font, Vector2(0, 16), "LV %d" % Progression.level,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.78, 0.45, 0.95))
	# the track + fill
	var track := Rect2(48, 8, 116, 7)
	draw_rect(track, Color(1, 1, 1, 0.12))
	draw_rect(Rect2(track.position, Vector2(track.size.x * _bar_fill, track.size.y)),
			Color(1.0, 0.62, 0.2, 0.9))
	# the level-up banner: a hot centre card
	if _banner_t > 0.0:
		var a := clampf(_banner_t / 0.6, 0.0, 1.0)
		var vp := get_viewport_rect().size
		var card := Rect2(vp.x * 0.5 - 170.0, vp.y * 0.30, 340.0, 30.0 + 34.0 * _banner_moves.size())
		draw_rect(Rect2(card.position - Vector2(6, 6), card.size + Vector2(12, 12)),
				Color(0.0, 0.01, 0.02, 0.55 * a))
		draw_rect(card, Color(0.02, 0.03, 0.05, 0.88 * a))
		draw_rect(Rect2(card.position, Vector2(3.0, card.size.y)),
				Color(1.0, 0.62, 0.2, a))
		draw_rect(Rect2(card.position + Vector2(card.size.x - 3.0, 0), Vector2(3.0, card.size.y)),
				Color(1.0, 0.62, 0.2, a))
		draw_string(font, card.position + Vector2(20, 26), "LEVEL %d" % _banner_level,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.78, 0.4, a))
		var y := 56.0
		for m in _banner_moves:
			draw_string(font, card.position + Vector2(20, y), "NEW: " + m["name"],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.9 * a))
			y += 34.0
