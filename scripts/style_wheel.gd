extends CanvasLayer

## The style-switch wheel (Batch 3, bible 4A: five styles, learned from
## people, never lost). Hold the world at bay, pick your school, get back
## to it: while the wheel is open time crawls (a fresh slow-mo beat every
## few seconds - never Engine.time_scale left dangling), the five styles
## sit as sectors around the centre, the current one lit, learned ones in
## their colour, locked ones grey with the level they open at. Tap a
## sector to switch; tap outside to change nothing. Style countering is a
## SOFT bonus: the wheel only ever changes which move list is live, never
## damage numbers.

const RADIUS := 150.0
const SECTOR_GAP := 0.06  # radians between sectors

var _open := false
var _beat_at_msec := 0
var _t := 0.0
var _shade: ColorRect
var _face: Control
var _chosen := false


func _ready() -> void:
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.0, 0.03, 0.55)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.gui_input.connect(_on_shade_input)
	add_child(_shade)
	_face = Control.new()
	_face.set_anchors_preset(Control.PRESET_CENTER)
	_face.custom_minimum_size = Vector2(RADIUS * 2.4, RADIUS * 2.4)
	_face.position = -_face.custom_minimum_size / 2.0
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.draw.connect(_draw_face)
	add_child(_face)


func open() -> void:
	if _open:
		return
	_open = true
	_chosen = false
	visible = true
	_beat_at_msec = Time.get_ticks_msec()
	Fx.slow_mo(3.5, 0.3)  # the world waits; re-issued while open
	Sound.play("ui_confirm_0", -8.0, 0.9, 0.05)
	Haptics.fire("ui")
	_face.queue_redraw()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	# the pick is made, the fight resumes at speed
	Fx.end_slow_mo()


func is_open() -> bool:
	return _open


func _process(_delta: float) -> void:
	if not _open:
		return
	# keep the crawl alive: a fresh beat before the 3.5 s expiry, so the
	# wheel never snaps back to full speed mid-pick. The beat MUST run on
	# the real clock - the world runs at 0.3 while open, so a beat timed
	# on the scaled delta fires at 9.3 s real, lapses the crawl at 3.5 s
	# (world-speed flicker) and aged past the 5 s watchdog (warn spam the
	# owner's phone read as errors).
	var now := Time.get_ticks_msec()
	if now - _beat_at_msec > 2800:
		_beat_at_msec = now
		Fx.slow_mo(3.5, 0.3)


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var p: Vector2 = event.position - _face.global_position \
				- _face.custom_minimum_size / 2.0
		# inside the ring: a sector pick; outside: cancel
		if p.length() <= RADIUS * 1.15:
			var idx := _sector_at(p.angle())
			if idx >= 0:
				_pick(idx)
				return
		close()
		Sound.play("ui_click_0", -10.0, 1.0, 0.03)


func _sector_at(ang: float) -> int:
	# screen angles run clockwise from +x; five sectors share the circle
	var a := ang
	while a < 0.0:
		a += TAU
	var step := TAU / 5.0
	# brawler starts at the top (-PI/2)
	var rel := a + PI / 2.0 + step / 2.0
	while rel < 0.0:
		rel += TAU
	var idx := int(rel / step) % 5
	if idx < 0 or idx >= Styles.STYLES.size():
		return -1
	return idx


func _pick(idx: int) -> void:
	var st: Dictionary = Styles.STYLES[idx]
	if not Styles.can_switch(st["id"]):
		# locked: the wheel says what it wants before it closes
		_flash_locked(st)
		Sound.play("ui_error_0", -8.0, 0.9, 0.04)
		return
	if Styles.switch_to(st["id"]):
		Sound.play("metal_ring_1", -8.0, 1.1, 0.06)
		Haptics.fire("heavy")
		Fx.burst((get_tree().get_first_node_in_group("player").global_position
				if get_tree().get_first_node_in_group("player") else Vector3.UP * 1.5)
				+ Vector3.UP * 1.4, st["color"])
		_chosen = true
	close()


func _flash_locked(st: Dictionary) -> void:
	_shade.color = Color(0.12, 0.0, 0.0, 0.6)
	var tw := create_tween()
	tw.tween_property(_shade, "color", Color(0.0, 0.0, 0.03, 0.55), 0.25)


func _draw_face() -> void:
	if not _open:
		return
	var c := _face.custom_minimum_size / 2.0
	var font := _face.get_theme_default_font()
	var step := TAU / 5.0
	for i in Styles.STYLES.size():
		var st: Dictionary = Styles.STYLES[i]
		var learned: bool = Styles.can_switch(st["id"])
		var is_current: bool = Styles.current == st["id"]
		var a0 := -PI / 2.0 + step * i + SECTOR_GAP
		var a1 := -PI / 2.0 + step * (i + 1) - SECTOR_GAP
		var col: Color = st["color"]
		if not learned:
			col = Color(0.32, 0.32, 0.34)
		if is_current:
			col = col.lightened(0.25)
		var alpha := 0.85 if (learned or is_current) else 0.45
		_face.draw_arc(c, RADIUS, a0, a1, 24, Color(col, alpha), 10.0)
		var mid := a0 + (a1 - a0) / 2.0
		var lp := c + Vector2(cos(mid), sin(mid)) * (RADIUS * 0.72)
		var name_col := Color(1, 1, 1, 0.95) if learned else Color(0.6, 0.6, 0.62, 0.8)
		if is_current:
			name_col = Color(col.r + 0.3, col.g + 0.3, col.b + 0.3, 1.0)
		_face.draw_string(font, lp - Vector2(40, 4), st["name"],
				HORIZONTAL_ALIGNMENT_CENTER, 80, 17, name_col)
		var teach := ("from %s" % st["teacher"]) if learned else \
				("LOCKED  lv %d" % int(st["unlock_level"]))
		_face.draw_string(font, lp + Vector2(-40, 16), teach,
				HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(0.75, 0.75, 0.78, 0.9))
	# the hub: what you are fighting as, right now
	var cur: Dictionary = Styles.current_def()
	_face.draw_string(font, c - Vector2(70, 26), "FIGHTING AS",
			HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color(0.7, 0.7, 0.73, 0.9))
	_face.draw_string(font, c - Vector2(70, -2), cur["name"],
			HORIZONTAL_ALIGNMENT_CENTER, 140, 20, cur["color"].lightened(0.2))
	_face.draw_string(font, c - Vector2(70, 22), "tap to switch",
			HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color(0.6, 0.6, 0.63, 0.8))
