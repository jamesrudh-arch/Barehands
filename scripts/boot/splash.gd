extends Control

## THE START SEQUENCE (V3 PART 0, composed entirely from built-in
## nodes in code — no external images, always renders on Mobile):
##   BLACK 0.3 s → the D'YOUNGS GAMES studio card (~3 s: a gold ring
##   draws itself around an inner ring, the DY monogram fades in, the
##   serif wordmark with wide spacing, a thin gold line draws, one
##   light sweep) → the content notice (MATURE THEMES 16+) → the
##   LEVERAGE title card (skyline silhouette, chromatic-split
##   wordmark, the tagline) → the menu.
## The full 3D key-art title scene lands at teardown step 13; this is
## the always-renders pass. Tap anywhere skips the current card; the
## sequence plays once per launch (Settings skip_intro honoured).

const STUDIO_NAME := "D'YOUNGS GAMES"

var phase := 0  # 0 black, 1 studio, 2 notice, 3 title
var _advance := false
var _cards: Array[Control] = []
var _ring: RingDrawer
var _sweep: SweepBand


func _ready() -> void:
	Game.set_state(Game.State.SPLASH)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_black_card()
	_build_studio_card()
	_build_notice_card()
	_build_title_card()
	for c in _cards:
		c.visible = false
	if bool(Settings.value("skip_intro")) and not _forced():
		Game.go_menu()
		return
	_run()


func _forced() -> bool:
	# the suite forces the sequence with this flag
	return bool(Settings.value("force_intro"))


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch and ev.pressed:
		_skip()
	elif ev is InputEventMouseButton and ev.pressed:
		_skip()


## Skip the current card (the public tap).
func _skip() -> void:
	_advance = true


## Wall-clock card timing: a 0.05 s poll timer under low fps takes
## longer than 0.05 s real, and counting iterations would stretch every
## card the same way (visible on a loaded phone). The clock is the truth.
func _wait_card(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if _advance:
			_advance = false
			return
		await get_tree().create_timer(0.05).timeout


func _run() -> void:
	# 1. black beat
	_show(0)
	await _wait_card(0.3)
	# 2. the studio card
	_show(1)
	_ring.progress = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_ring, "progress", 1.0, 1.1)
	_sweep.run(1.6, 0.4)
	await _wait_card(3.0)
	# 3. the content notice
	_show(2)
	await _wait_card(2.0)
	# 4. the title card
	_show(3)
	await _wait_card(4.0)
	Game.go_menu()


func _show(i: int) -> void:
	phase = i
	for j in _cards.size():
		_cards[j].visible = j == i


# --- card builders ------------------------------------------------------------


## Cards align 1:1 with phases: [black, studio, notice, title]. The
## black card is the half-second beat before the studio card.
func _build_black_card() -> void:
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	add_child(card)
	_cards.append(card)


func _serif(size: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = ["Georgia", "Times New Roman", "serif"]
	return f


func _label(text: String, size: int, color: Color, font: Font,
		spaced := false) -> Label:
	var l := Label.new()
	l.text = " ".join(text.split("")) if spaced else text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	return l


func _build_studio_card() -> void:
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	# the gold ring that draws itself, around an inner static ring
	_ring = RingDrawer.new()
	_ring.set_anchors_preset(Control.PRESET_CENTER)
	_ring.custom_minimum_size = Vector2(280, 280)
	_ring.position = Vector2(size.x * 0.5 - 140, size.y * 0.5 - 210)
	_ring.modulate = Color(1, 1, 1, 0)
	card.add_child(_ring)
	var tw_in := create_tween()
	tw_in.tween_property(_ring, "modulate:a", 1.0, 0.6)
	# the DY monogram at the ring's centre
	var mono := _label("DY", 64, Color(0.79, 0.64, 0.29), _serif(64))
	mono.position = Vector2(size.x * 0.5 - 40, size.y * 0.5 - 192)
	card.add_child(mono)
	# the wordmark
	var word := _label("D'YOUNGS", 58, Color(0.91, 0.85, 0.66),
			_serif(58), true)
	word.position = Vector2(0, size.y * 0.5 - 40)
	word.size = Vector2(size.x, 70)
	card.add_child(word)
	var sub := _label("GAMES", 26, Color(0.79, 0.64, 0.29),
			_serif(26), true)
	sub.position = Vector2(0, size.y * 0.5 + 30)
	sub.size = Vector2(size.x, 40)
	card.add_child(sub)
	# the thin gold line that draws beneath
	var line := LineDrawer.new()
	line.set_anchors_preset(Control.PRESET_CENTER)
	line.custom_minimum_size = Vector2(360, 2)
	line.position = Vector2(size.x * 0.5 - 180, size.y * 0.5 + 86)
	card.add_child(line)
	var tw_line := create_tween()
	tw_line.tween_property(line, "progress", 1.0, 1.0).set_delay(0.9)
	# one light sweep across the wordmark
	_sweep = SweepBand.new()
	_sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(_sweep)
	add_child(card)
	_cards.append(card)


func _build_notice_card() -> void:
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	var f := SystemFont.new()
	f.font_names = ["Helvetica Neue", "Arial", "sans-serif"]
	var main := _label("MATURE THEMES 16+", 44, Color(0.92, 0.92, 0.96), f)
	main.position = Vector2(0, size.y * 0.5 - 60)
	main.size = Vector2(size.x, 60)
	card.add_child(main)
	var sub := _label("Stylized violence, crime, strong language", 22,
			Color(0.6, 0.62, 0.72), f)
	sub.position = Vector2(0, size.y * 0.5 + 10)
	sub.size = Vector2(size.x, 34)
	card.add_child(sub)
	add_child(card)
	_cards.append(card)


func _build_title_card() -> void:
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.024, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	card.add_child(Skyline.new())
	# the chromatic-split wordmark: cyan left, magenta right, white centre
	var f := SystemFont.new()
	f.font_names = ["Arial Black", "Arial", "sans-serif"]
	for off in [Vector2(-4, 0), Vector2(4, 0), Vector2.ZERO]:
		var c := Color(0, 0.94, 1.0) if off.x < 0 \
				else Color(1.0, 0, 0.5) if off.x > 0 \
				else Color(0.95, 0.96, 0.99)
		var l := _label("LEVERAGE", 96, c, f)
		l.position = Vector2(off.x, size.y * 0.36 + off.y)
		l.size = Vector2(size.x, 110)
		l.z_index = 10 if off == Vector2.ZERO else 9
		card.add_child(l)
	var tag := _label("Everyone has leverage on you.", 24,
			Color(0.77, 0.79, 0.9), f)
	tag.position = Vector2(0, size.y * 0.36 + 130)
	tag.size = Vector2(size.x, 40)
	card.add_child(tag)
	var prod := _label("A %s production" % STUDIO_NAME, 18,
			Color(0.55, 0.56, 0.68), _serif(18), true)
	prod.position = Vector2(0, size.y - 60)
	prod.size = Vector2(size.x, 26)
	card.add_child(prod)
	add_child(card)
	_cards.append(card)


# --- the drawn pieces -----------------------------------------------------------


## A gold ring that draws its sweep as `progress` goes 0→1, around a
## static inner ring (pure _draw, no textures).
class RingDrawer:
	extends Control
	var progress := 0.0
	const GOLD := Color(0.79, 0.64, 0.29)

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, size.x * 0.5 - 6.0, -PI / 2,
				-PI / 2 + TAU * clampf(progress, 0.0, 1.0),
				96, GOLD, 3.0, true)
		draw_arc(c, size.x * 0.5 - 26.0, 0, TAU, 96,
				GOLD.darkened(0.35), 2.0, true)


## A horizontal gold line that draws left→right.
class LineDrawer:
	extends Control
	var progress := 0.0

	func _draw() -> void:
		if progress <= 0.0:
			return
		draw_line(Vector2.ZERO,
				Vector2(size.x * clampf(progress, 0.0, 1.0), 0),
				Color(0.79, 0.64, 0.29), 2.0)


## One soft light band sweeping across the card, once per call.
class SweepBand:
	extends Control
	var _t := 0.0
	var _running := false

	func run(delay: float, dur: float) -> void:
		await get_tree().create_timer(delay).timeout
		_t = 0.0
		_running = true
		while _t < dur:
			_t += get_process_delta_time()
			queue_redraw()
			await get_tree().process_frame
		_running = false
		queue_redraw()

	func _draw() -> void:
		if not _running:
			return
		var x := remap(clampf(_t / 0.4, 0.0, 1.0), 0.0, 1.0,
				-size.x * 0.3, size.x * 1.3)
		var pts := PackedVector2Array([Vector2(x, 0), Vector2(x + 90, 0),
				Vector2(x + 150, size.y), Vector2(x + 60, size.y)])
		var cols := PackedColorArray([
				Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.14),
				Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.0)])
		draw_polygon(pts, cols)


## The title-card skyline: dark building silhouettes with a few neon
## windows and a haze band (drawn, not textured).
class Skyline:
	extends Control

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var y := size.y
		var x := 0.0
		while x < size.x:
			var w := rng.randf_range(40, 110)
			var h := rng.randf_range(90, 240)
			draw_rect(Rect2(x, y - h, w, h),
					Color(0.03, 0.035, 0.085))
			# neon windows
			for i in int(h / 46.0):
				for j in int(w / 30.0):
					if rng.randf() < 0.16:
						var wc := Color(1.0, 0.03, 0.5) \
								if rng.randf() < 0.5 \
								else Color(0.0, 0.94, 1.0)
						draw_rect(Rect2(x + 8 + j * 26,
								y - h + 12 + i * 42, 8, 12), wc)
			x += w + rng.randf_range(6, 26)
		draw_rect(Rect2(0, y - 300, size.x, 300),
				Color(0.5, 0.1, 0.4, 0.05))
