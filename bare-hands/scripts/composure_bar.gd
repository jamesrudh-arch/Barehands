class_name ComposureBar
extends Control
## The Composure bar (Batch 2): bottom-centre, above the thumb zone - a
## wide flat strip that reads at a glance in a fight. Gold while healthy,
## orange under half, red under a quarter; when the GUARD BREAKS the strip
## empties and a jagged "GUARD BROKEN" flash sells the mistake. Follows
## the LevelBar pattern: a Control in main.tscn that draws itself.

const W := 180.0
const H := 7.0

var _flash_t := 0.0


func _ready() -> void:
	add_to_group("composure_bar")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -W / 2.0
	offset_right = W / 2.0
	offset_top = -84.0
	offset_bottom = -77.0
	Composure.changed.connect(_on_changed)
	Composure.guard_broke.connect(_on_break)
	_on_changed(Composure.value)
	# draw below the style/toast layers, above the game
	z_index = 5


func _on_changed(_v: float) -> void:
	queue_redraw()


func _on_break() -> void:
	_flash_t = 1.2
	Sound.play("sub_hit_1", -8.0, 0.7)


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var frac := clampf(Composure.value / Tuning.v("composure_max"), 0.0, 1.0)
	var r := Rect2(Vector2.ZERO, Vector2(W, H))
	draw_rect(r, Color(0.04, 0.04, 0.05, 0.75))  # the track
	var col := Color(1.0, 0.82, 0.25)  # gold: healthy
	if frac < 0.5:
		col = Color(1.0, 0.55, 0.2)  # orange: pressure
	if frac < 0.25 or Composure.guard_broken():
		col = Color(1.0, 0.25, 0.2)  # red: about to break / broken
	if frac > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W * frac, H)), col)
	if Composure.guard_broken():
		# the guard is shattered: outline the empty strip and flash the tell
		draw_rect(r, Color(1.0, 0.25, 0.2, 0.4 + 0.6 * _flash_t), false, 1.5)
		if _flash_t > 0.0:
			var font := get_theme_default_font()
			draw_string(font, Vector2(0, -10), "GUARD BROKEN",
					HORIZONTAL_ALIGNMENT_CENTER, W, int(18 + 8 * _flash_t),
					Color(1.0, 0.3, 0.2, minf(_flash_t, 1.0)))
	elif frac < 1.0 and frac > 0.0:
		# the calm-regen shimmer on the leading edge
		draw_rect(Rect2(Vector2(W * frac - 1.5, 0.0), Vector2(1.5, H)),
				Color(1, 1, 1, 0.35))
