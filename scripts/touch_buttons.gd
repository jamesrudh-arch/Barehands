extends CanvasLayer
const CLS_ActionButton := preload("res://scripts/action_button.gd")
const CLS_SettingsUI := preload("res://scripts/settings_ui.gd")
const CLS_StyleWheel := preload("res://scripts/style_wheel.gd")
const CLS_Enemy := preload("res://scripts/enemy.gd")
## The action side of the HUD (Stage A + combo pass + the B18 layout
## engine). Two button schemes the player chooses in Settings and the
## first-run picker:
##   face    - the console diamond: A light punch, B heavy punch, X kick,
##             Y grab/throw, with smaller JUMP / DODGE / SPRINT / LOCK
##             beside it. The SUPER button only appears when the meter is
##             full.
##   classic - LIGHT (tap) and HEAVY (its own button), DODGE, JUMP,
##             SPRINT, LOCK, SUPER with its fill ring. GRAB is
##             CONTEXTUAL: it appears (as GRAB / INTERACT / TALK /
##             THROW) only when something is in range - the hero's
##             context_action() answers at 10 Hz.
##
## THE B18 LAYOUT ENGINE (the fix for the phone's stacked, doubled,
## bunched buttons): one right-anchored grid of slots. The cluster is
## fitted into the safe area AS A WHOLE - the old per-button clamp
## pushed several buttons onto the same spot, which read as doubled
## labels - sizes never drop below 64 canvas px, and a bounded pairwise
## pass guarantees no two visible buttons overlap, whatever the layout
## editor's saved overrides say. STYLE and PHONE sit in their own
## column, clearly separated from the attack cluster. Both schemes keep
## touch-DOWN firing, oversized hit areas, press animation, the ui tick,
## haptics, cooldown rings, the layout editor and left-handed mode.

const CLASSIC_SPECS := [
	# name, label, sub, colour, slot (col, row from bottom-right), size
	["PunchBtn", "LIGHT", "", Color(1.0, 0.45, 0.35, 0.95), Vector2(0, 0), 132.0],
	["DodgeBtn", "DODGE", "", Color(0.85, 0.9, 1.0, 0.95), Vector2(1, 0), 108.0],
	["HeavyBtn", "HEAVY", "", Color(1.0, 0.62, 0.3, 0.95), Vector2(0, 1), 118.0],
	["GrabBtn", "GRAB", "", Color(0.75, 1.0, 0.6, 0.95), Vector2(1, 1), 96.0],
	["JumpBtn", "JUMP", "", Color(1.0, 0.78, 0.45, 0.95), Vector2(0, 2), 84.0],
	["SprintBtn", "SPRINT", "", Color(0.55, 0.95, 1.0, 0.95), Vector2(1, 2), 84.0],
	["SuperBtn", "SUPER", "", Color(1.0, 0.62, 0.2, 1.0), Vector2(2, 0), 100.0],
	["LockBtn", "LOCK", "", Color(0.8, 0.8, 0.85, 0.9), Vector2(2, 1), 76.0],
	["StyleBtn", "STYLE", "", Color(0.9, 0.7, 0.4, 0.9), Vector2(2, 2), 78.0],
	["PhoneBtn", "PHONE", "", Color(0.45, 0.52, 0.62, 1.0), Vector2(3, 1), 68.0],
	# B18 6C: guidance buttons - top row of the cluster, away from attacks
	["ObjBtn", "OBJECTIVE", "", Color(1.0, 0.85, 0.2, 0.9), Vector2(2, 3), 64.0],
	["HelpBtn", "HELP", "", Color(0.6, 0.85, 1.0, 0.9), Vector2(3, 3), 64.0],
]

const FACE_SPECS := [
	# the diamond: A bottom-centre, B right, X left, Y top
	["FaceA", "A", "LIGHT", Color(1.0, 0.82, 0.6, 0.95), Vector2(1, 0), 116.0],
	["FaceB", "B", "HEAVY", Color(1.0, 0.42, 0.34, 0.95), Vector2(0, 1), 108.0],
	["FaceX", "X", "KICK", Color(0.45, 0.92, 1.0, 0.95), Vector2(2, 1), 108.0],
	["FaceY", "Y", "GRAB", Color(0.72, 1.0, 0.62, 0.95), Vector2(1, 2), 108.0],
	["DodgeBtn", "DODGE", "", Color(0.85, 0.9, 1.0, 0.95), Vector2(0, 0), 96.0],
	["SuperBtn", "SUPER", "", Color(1.0, 0.62, 0.2, 1.0), Vector2(2, 0), 96.0],
	["JumpBtn", "JUMP", "", Color(1.0, 0.78, 0.45, 0.95), Vector2(3, 0), 84.0],
	["SprintBtn", "SPRINT", "", Color(0.55, 0.95, 1.0, 0.95), Vector2(3, 1), 84.0],
	["LockBtn", "LOCK", "", Color(0.8, 0.8, 0.85, 0.9), Vector2(2, 2), 74.0],
	["StyleBtn", "STYLE", "", Color(0.9, 0.7, 0.4, 0.9), Vector2(3, 2), 78.0],
	["PhoneBtn", "PHONE", "", Color(0.45, 0.52, 0.62, 1.0), Vector2(0, 2), 68.0],
	["ObjBtn", "OBJECTIVE", "", Color(1.0, 0.85, 0.2, 0.9), Vector2(2, 3), 64.0],
	["HelpBtn", "HELP", "", Color(0.6, 0.85, 1.0, 0.9), Vector2(3, 3), 64.0],
]

## B18.3 Part 2 (BUG 8): the FIGHTING scheme - the console diamond
## (X punch, Y heavy, B kick, A dodge), the GUARD/GRAB/SPRINT pills in
## a row above it, JUMP to the left, SUPER in the diamond's centre,
## STYLE (hold: the wheel), LOCK, PHONE. B becomes the context action
## near doors and pickups (combat keeps it KICK). Default scheme.
const FIGHT_SPECS := [
	# the diamond: Y top, X left, B right, A bottom
	["FightX", "X", "PUNCH", Color(0.55, 0.85, 1.0, 0.95), Vector2(1, 1), 108.0],
	["FightY", "Y", "HEAVY", Color(1.0, 0.82, 0.35, 0.95), Vector2(2, 2), 108.0],
	["FightB", "B", "KICK", Color(1.0, 0.45, 0.35, 0.95), Vector2(3, 1), 108.0],
	["FightA", "A", "DODGE", Color(0.6, 1.0, 0.75, 0.95), Vector2(2, 0), 96.0],
	["SuperBtn", "SUPER", "", Color(1.0, 0.62, 0.2, 1.0), Vector2(2, 1), 64.0],
	["JumpBtn", "JUMP", "vault", Color(1.0, 0.78, 0.45, 0.95), Vector2(0, 1), 76.0],
	["GuardBtn", "GUARD", "hold", Color(0.8, 0.85, 1.0, 0.9), Vector2(1, 3), 68.0],
	["GrabBtn", "GRAB", "", Color(0.75, 1.0, 0.6, 0.95), Vector2(2, 3), 68.0],
	["SprintBtn", "SPRINT", "hold", Color(0.55, 0.95, 1.0, 0.95), Vector2(3, 3), 68.0],
	["StyleBtn", "STYLE", "hold", Color(0.9, 0.7, 0.4, 0.9), Vector2(0, 2), 72.0],
	["LockBtn", "LOCK", "", Color(0.8, 0.8, 0.85, 0.9), Vector2(3, 2), 64.0],
	["PhoneBtn", "PHONE", "", Color(0.45, 0.52, 0.62, 1.0), Vector2(0, 3), 60.0],
	["ObjBtn", "OBJECTIVE", "", Color(1.0, 0.85, 0.2, 0.9), Vector2(1, 0), 64.0],
	["HelpBtn", "HELP", "", Color(0.6, 0.85, 1.0, 0.9), Vector2(3, 0), 64.0],
]

const GAP := 18.0        # between grid cells
const MARGIN := 16.0     # from the safe-area corner
const MIN_SIZE := 64.0   # canvas px; a thumb must be able to find it

var hint_shown := false
var _hint_fade := 0.0
var _buttons: Dictionary = {}  # name -> ActionButton
var _default_rects: Dictionary = {}  # name -> Rect2 before any override
var _b_ctx := ""  # B18.3: the FIGHT scheme's live context verb for B
var _editing := false
var _edit_sel := ""
var _edit_drag := false
var _edit_last := Vector2.ZERO
var _toolbar: PanelContainer
var _hint: Label
var _vp: Vector2
var _ctx_acc := 0.0


func _ready() -> void:
	add_to_group("hud_buttons")
	# B17/B18: rotate the phone or resize the window and the whole
	# cluster re-lays out into the new safe area (as ONE unit)
	get_viewport().size_changed.connect(_layout_cluster)
	_vp = get_viewport().size
	_build_buttons()
	_build_hint()
	_apply_layout()
	Settings.changed.connect(_on_setting)
	SuperMeter.changed.connect(_on_super_meter)
	_on_super_meter(SuperMeter.value)


func _scheme() -> String:
	var s := str(Settings.value("button_scheme"))
	# Gate A: the FIGHTING scheme (X PUNCH / Y HEAVY / B KICK / A DODGE)
	# is the default - the phone showed the CLASSIC word buttons because
	# an unset setting fell through to "classic"
	return s if s in ["face", "fight", "classic"] else "fight"


func _specs() -> Array:
	match _scheme():
		"face":
			return FACE_SPECS
		"fight":
			return FIGHT_SPECS
	return CLASSIC_SPECS


func _spec_for(name: String) -> Array:
	for spec in _specs():
		if spec[0] == name:
			return spec
	return []


func _on_setting(key: String) -> void:
	if key == "button_scheme":
		_build_buttons()
		_apply_layout()
	elif key == "button_scale":
		# rebuilt rects (the default positions carry the size); the
		# stored mirror offsets were computed against the old rects, so
		# a left-handed layout re-mirrors after the rebuild
		_build_buttons()
		if Settings.value("left_handed"):
			apply_preset("left")
		_apply_layout()
	elif key == "layout" or key == "left_handed" or key == "opacity":
		_apply_layout()


# --- buttons ---------------------------------------------------------------------


func _build_buttons() -> void:
	for name in _buttons:
		(_buttons[name] as CLS_ActionButton).queue_free()
	_buttons.clear()
	_default_rects.clear()
	for spec in _specs():
		var name: String = spec[0]
		var b := CLS_ActionButton.new()
		b.name = name
		b.label = spec[1]
		b.sub = spec[2]
		b.tint = spec[3]
		b.down.connect(_on_down.bind(name))
		b.up.connect(_on_up.bind(name))
		_buttons[name] = b
		add_child(b)
		_default_rects[name] = Rect2()
	_layout_cluster()
	_apply_super_visibility()


func _on_down(name: String) -> void:
	if _editing:
		return
	Sound.play("ui_click_0", -12.0, 1.0, 0.03)
	Haptics.fire("ui")
	match name:
		"JumpBtn":
			InputBus.queue_jump()
		"SprintBtn":
			InputBus.press_sprint()
		"PunchBtn":
			InputBus.stamp_action("punch_down")
			InputBus.punch_press()
			InputBus.press_face("A")
		"HeavyBtn":
			InputBus.stamp_action("punch_down")
			InputBus.queue_heavy()
			InputBus.press_face("B")
		"DodgeBtn":
			InputBus.stamp_action("dodge_down")
			InputBus.dodge_press()
		"GrabBtn", "FaceY":
			InputBus.queue_grab()
			InputBus.press_face("Y")
		"LockBtn":
			_toggle_lock()
		"SuperBtn":
			InputBus.queue_super()
		"PhoneBtn":
			Phone.toggle_open()  # the ring banner answers itself
		"StyleBtn":
			_open_wheel()
		"FaceA":
			InputBus.stamp_action("punch_down")
			InputBus.queue_punch()
			InputBus.press_face("A")
		"FaceB":
			InputBus.stamp_action("punch_down")
			InputBus.queue_heavy()
			InputBus.press_face("B")
		"FaceX":
			InputBus.queue_kick()
			InputBus.press_face("X")
		# --- B18.3 Part 2: the FIGHTING scheme --------------------------------
		"FightX":
			InputBus.stamp_action("punch_down")
			InputBus.queue_punch()
			InputBus.press_face("A")   # X = the light attack (combo token A)
		"FightY":
			# tap = instant heavy, hold = the charged heavy (hold poll)
			InputBus.stamp_action("punch_down")
			InputBus.punch_press()
			InputBus.press_face("B")   # Y = the heavy (combo token B)
		"FightB":
			# B is KICK - but near a door/pickup (and out of combat) it
			# becomes the context action instead (Part 6D priority rule)
			if _b_context() != "":
				InputBus.queue_grab()
			else:
				InputBus.queue_kick()
				InputBus.press_face("X")   # B = the kick (combo token X)
		"FightA":
			InputBus.stamp_action("dodge_down")
			InputBus.dodge_press()
		"GuardBtn":
			# hold to block (a block's first moments parry); never rolls
			InputBus.dodge_press()
		"ObjBtn":
			_guide_call("objective_pressed")
		"HelpBtn":
			_guide_call("help_pressed")


func _on_up(name: String) -> void:
	if _editing:
		return
	match name:
		"SprintBtn":
			InputBus.release_sprint()
		"PunchBtn":
			InputBus.punch_release()
		"DodgeBtn":
			InputBus.dodge_release()
		"FightY":
			# quick tap: drop the light the release queues, fire the
			# instant heavy; long hold: the charged heavy already fired
			var quick := InputBus.punch_age() >= 0.0 \
					and InputBus.punch_age() * 1000.0 < InputBus.PUNCH_HOLD_MSEC
			InputBus.punch_release()
			if quick:
				InputBus.clear_punch_queue()
				InputBus.queue_heavy()
		"FightA":
			InputBus.dodge_release()
		"GuardBtn":
			# a quick guard tap never rolls - drop the queued dodge
			var g_quick := InputBus.dodge_age() >= 0.0 \
					and InputBus.dodge_age() * 1000.0 < Tuning.v("block_hold_ms")
			InputBus.dodge_release()
			if g_quick:
				InputBus.clear_dodge_queue()


## The style wheel (Batch 3): one shared instance, code-built.
func _open_wheel() -> void:
	var w := get_tree().root.get_node_or_null("StyleWheel") as CLS_StyleWheel
	if w == null:
		w = CLS_StyleWheel.new()
		w.name = "StyleWheel"
		get_tree().root.add_child.call_deferred(w)
		await get_tree().process_frame
	if w:
		w.open()


func _toggle_lock() -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam:
		cam.toggle_lock()


## B18 6C: the guidance buttons reach the guide node (it may be absent -
## SafeBoot, tests - in which case the tap is a no-op).
func _guide_call(method: String) -> void:
	var g := get_tree().get_first_node_in_group("guide")
	if g and g.has_method(method):
		g.call(method)


# --- per-frame state: cooldown rings, the contextual GRAB ------------------------


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var p := player as CharacterBody3D
		_set_ring("PunchBtn", p.punch_cooldown_01())
		_set_ring("DodgeBtn", p.dodge_cooldown_01())
		_set_ring("FaceA", p.punch_cooldown_01())
		_set_ring("FaceB", p.punch_cooldown_01())
		_set_ring("FaceX", p.punch_cooldown_01())
		_set_ring("FightX", p.punch_cooldown_01())
		_set_ring("FightY", p.punch_cooldown_01())
		_set_ring("FightB", p.punch_cooldown_01())
		_set_ring("FightA", p.dodge_cooldown_01())
	if _hint_fade > 0.0:
		_hint_fade -= delta
		if _hint_fade <= 0.0:
			_hint.visible = false
		elif _hint_fade < 0.5:
			_hint.modulate.a = _hint_fade / 0.5
	# B18: the classic GRAB button is contextual - it only exists when
	# something answers (the hero's context_action, 10 Hz, never fires)
	_ctx_acc += delta
	if _ctx_acc >= 0.1:
		_ctx_acc = 0.0
		_apply_context()


func _set_ring(name: String, cd: float) -> void:
	var b := _buttons.get(name) as CLS_ActionButton
	if b:
		b.cooldown = cd


## B18 (Part 2.2): GRAB / INTERACT / TALK / THROW, shown only when
## usable. The face scheme's Y keeps its diamond slot (its label stays
## GRAB); classic's dedicated button appears and disappears.
func _apply_context() -> void:
	var want := ""
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("context_action"):
		want = str(player.call("context_action"))
	# B18.3 Part 6D: B keeps KICK while a fight is close (no door opens
	# by accident); the context wins only when the street is calm
	if want != "" and _combat_near(6.0):
		want = ""
	_b_ctx = want
	var b := _buttons.get("GrabBtn") as CLS_ActionButton
	if b:
		if want == "":
			b.visible = false
		else:
			b.visible = true
			b.label = want
	# the FIGHT scheme's B button wears the context verb when it has one
	var fb := _buttons.get("FightB") as CLS_ActionButton
	if fb:
		fb.sub = want if want != "" else "KICK"


## The context verb for B right now ("" = none / combat priority).
func _b_context() -> String:
	return _b_ctx


## True when a live enemy stands within `radius` metres of the hero -
## the combat-priority rule that keeps B as KICK mid-fight.
func _combat_near(radius: float) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("state") == CLS_Enemy.State.DOWN:
			continue
		if (e as Node3D).global_position.distance_to(player.global_position) < radius:
			return true
	return false


func _on_super_meter(value: float) -> void:
	var b := _buttons.get("SuperBtn") as CLS_ActionButton
	if b == null:
		return
	b.charged = SuperMeter.is_full()
	# the ring shows the FILL (drains as the meter grows)
	b.cooldown = 1.0 - SuperMeter.frac()
	_apply_super_visibility()


## Face scheme: the SUPER button only exists on screen while the meter is
## full; Classic keeps it visible with its fill ring.
func _apply_super_visibility() -> void:
	var b := _buttons.get("SuperBtn") as CLS_ActionButton
	if b:
		b.visible = _scheme() == "classic" or SuperMeter.is_full()


# --- the B18 layout engine ---------------------------------------------------------


## Desired rects from the specs (grid slots, bottom-right anchored),
## then the stored editor overrides, then: fit the WHOLE cluster into
## the safe area, resolve any pairwise overlap, floor the sizes.
func _layout_cluster() -> void:
	if _buttons.is_empty():
		return
	var safe := _safe_rect()
	var scale: float = clampf(float(Settings.value("button_scale")), 0.6, 1.6)
	var cell := 132.0 * scale + GAP
	for name in _buttons:
		var b := _buttons[name] as CLS_ActionButton
		var spec := _spec_for(name)
		if spec.is_empty():
			continue
		var slot: Vector2 = spec[4]
		var sz: float = maxf(spec[5] * scale, MIN_SIZE)
		var x: float = safe.end.x - MARGIN - (slot.x + 1.0) * cell \
				+ (cell - sz) * 0.5
		var y: float = safe.end.y - MARGIN - (slot.y + 1.0) * cell \
				+ (cell - sz) * 0.5
		b.size = Vector2(sz, sz)
		b.position = Vector2(x, y)
		_default_rects[name] = Rect2(b.position, b.size)
	_apply_layout()


## Overrides from the layout editor, then the cluster fit + overlap
## resolve. (Nothing here clamps a single button on its own - that was
## the stacking bug.)
func _apply_layout() -> void:
	if _buttons.is_empty():
		return
	var opacity: float = float(Settings.value("opacity"))
	for name in _buttons:
		var b := _buttons[name] as CLS_ActionButton
		var over: Dictionary = Settings.layout_for(name)
		b.position = _default_rects[name].position + Vector2(
				float(over.get("dx", 0.0)), float(over.get("dy", 0.0)))
		b.size = _default_rects[name].size * float(over.get("scale", 1.0))
		b.modulate = Color(1, 1, 1, opacity * float(over.get("opacity", 1.0)))
	_fit_cluster()
	_resolve_overlaps()
	_apply_super_visibility()
	_apply_context()


## The safe area rect in canvas coordinates. A degenerate report
## (headless reports (0,0,0,0)) falls back to the full visible rect so
## the layout stays sane everywhere.
func _safe_rect() -> Rect2:
	var ft := get_viewport().get_final_transform().affine_inverse()
	var safe: Rect2 = ft * Rect2(DisplayServer.get_display_safe_area())
	safe = safe.intersection(get_viewport().get_visible_rect())
	if safe.size.x < 8.0 or safe.size.y < 8.0:
		return get_viewport().get_visible_rect()
	return safe


## Shift the WHOLE cluster inside the safe area (one unit, never button
## by button - the per-button clamp is what stacked them on the phone).
func _fit_cluster() -> void:
	var safe := _safe_rect()
	if safe.size.x < 8.0 or safe.size.y < 8.0:
		return  # headless / degenerate: leave the layout alone
	var box := Rect2()
	var first := true
	for name in _buttons:
		var b := _buttons[name] as CLS_ActionButton
		var r := Rect2(b.position, b.size)
		box = r if first else box.merge(r)
		first = false
	if box.size.x < 8.0 or box.size.y < 8.0:
		return
	var d := Vector2.ZERO
	if box.end.x > safe.end.x:
		d.x = safe.end.x - box.end.x
	if box.position.x + d.x < safe.position.x:
		d.x = safe.position.x - box.position.x
	if box.end.y > safe.end.y:
		d.y = safe.end.y - box.end.y
	if box.position.y + d.y < safe.position.y:
		d.y = safe.position.y - box.position.y
	if d != Vector2.ZERO:
		for name in _buttons:
			(_buttons[name] as CLS_ActionButton).position += d


## Bounded pairwise pass: no two visible buttons may share pixels,
## whatever the saved overrides and sizes say. Overlapping pairs get
## pushed apart along the cheaper axis.
func _resolve_overlaps() -> void:
	for pass_i in range(8):
		var moved := false
		var names := _buttons.keys()
		for i in range(names.size()):
			for j in range(i + 1, names.size()):
				var a := _buttons[names[i]] as CLS_ActionButton
				var b := _buttons[names[j]] as CLS_ActionButton
				if not a.visible or not b.visible:
					continue
				var ra := Rect2(a.position, a.size)
				var rb := Rect2(b.position, b.size)
				if not ra.intersects(rb):
					continue
				# push b out of a, along the cheaper axis
				var left := ra.position.x - rb.end.x   # <= 0
				var up := ra.position.y - rb.end.y     # <= 0
				if absf(left) <= absf(up):
					b.position.x += left - 2.0
				else:
					b.position.y += up - 2.0
				moved = true
		if not moved:
			break


# --- the layout editor ---------------------------------------------------------------


func begin_layout_edit() -> void:
	_editing = true
	_edit_sel = ""
	for name in _buttons:
		(_buttons[name] as CLS_ActionButton).editable = true
	_build_toolbar()


func end_layout_edit() -> void:
	_editing = false
	for name in _buttons:
		(_buttons[name] as CLS_ActionButton).editable = false
	if _toolbar:
		_toolbar.queue_free()
		_toolbar = null
	_apply_layout()


func _build_toolbar() -> void:
	_toolbar = PanelContainer.new()
	_toolbar.anchor_left = 0.5
	_toolbar.anchor_right = 0.5
	_toolbar.anchor_top = 0.0
	_toolbar.anchor_bottom = 0.0
	_toolbar.offset_left = -230.0
	_toolbar.offset_right = 230.0
	_toolbar.offset_top = 12.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.92)
	sb.border_color = Color(1, 0.58, 0.13, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	_toolbar.add_theme_stylebox_override("panel", sb)
	add_child(_toolbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_toolbar.add_child(row)

	var sel := Label.new()
	sel.name = "SelLabel"
	sel.text = "none"
	sel.custom_minimum_size = Vector2(90, 0)
	sel.add_theme_font_size_override("font_size", 13)
	row.add_child(sel)
	_edit_btn(row, "  -  ", func() -> void: _nudge_scale(-0.08))
	_edit_btn(row, "  +  ", func() -> void: _nudge_scale(0.08))
	var sl := HSlider.new()
	sl.min_value = 0.3
	sl.max_value = 1.0
	sl.step = 0.05
	sl.custom_minimum_size = Vector2(110, 32)
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float) -> void: _set_opacity(v))
	row.add_child(sl)
	_edit_btn(row, "DONE", func() -> void:
		end_layout_edit()
		var s := get_tree().get_first_node_in_group("settings_ui") as CLS_SettingsUI
		if s:
			s.open())
	var lbl := Label.new()
	lbl.text = "drag a button; tap to select"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.7))
	row.add_child(lbl)


func _edit_btn(row: BoxContainer, text: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(52, 40)
	b.pressed.connect(fn)
	row.add_child(b)


func _input(event: InputEvent) -> void:
	if not _editing:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_edit_sel = _button_at(event.position)
			_edit_drag = _edit_sel != ""
			_edit_last = event.position
			_update_sel_label()
		elif _edit_drag and _edit_sel != "":
			_save_override(_edit_sel)
			_edit_drag = false
	elif event is InputEventScreenDrag and _edit_drag and _edit_sel != "":
		var b := _buttons[_edit_sel] as CLS_ActionButton
		b.position += event.position - _edit_last
		_edit_last = event.position


func _button_at(pos: Vector2) -> String:
	for name in _buttons:
		var b := _buttons[name] as CLS_ActionButton
		if Rect2(b.position, b.size).has_point(pos):
			return name
	return ""


func _update_sel_label() -> void:
	if _toolbar:
		var l := _toolbar.find_children("SelLabel", "Label", true, false)
		if l.size() > 0:
			(l[0] as Label).text = _edit_sel if _edit_sel != "" else "none"


func _nudge_scale(d: float) -> void:
	if _edit_sel == "":
		return
	var over := Settings.layout_for(_edit_sel)
	over["scale"] = clampf(float(over.get("scale", 1.0)) + d, 0.6, 1.6)
	Settings.set_layout_for(_edit_sel, over)
	_apply_layout()


func _set_opacity(v: float) -> void:
	if _edit_sel == "":
		return
	var over := Settings.layout_for(_edit_sel)
	over["opacity"] = v
	Settings.set_layout_for(_edit_sel, over)
	_apply_layout()


func _save_override(name: String) -> void:
	var b := _buttons[name] as CLS_ActionButton
	var def: Rect2 = _default_rects[name]
	var over := Settings.layout_for(name)
	over["dx"] = b.position.x - def.position.x
	over["dy"] = b.position.y - def.position.y
	Settings.set_layout_for(name, over)


## Presets are generic over whichever buttons exist (both schemes).
func apply_preset(id: String) -> void:
	Settings.set_value("preset", id)
	var layout := {}
	match id:
		"compact":
			for name in _buttons:
				layout[name] = {"dx": 34.0, "dy": 30.0, "scale": 0.85, "opacity": 1.0}
		"left":
			# mirror every button horizontally around the screen centre
			for name in _buttons:
				var def: Rect2 = _default_rects[name]
				var cx := def.position.x + def.size.x * 0.5
				layout[name] = {"dx": _vp.x - 2.0 * cx, "dy": 0.0, "scale": 1.0, "opacity": 1.0}
	Settings.set_value("layout", layout)
	Settings.set_value("left_handed", id == "left")
	Settings.changed.emit("layout")


# --- hints ---------------------------------------------------------------------------


## Called by the hero the first time the player stands near a climbable edge.
func show_hint(text: String, dur := 2.8) -> void:
	hint_shown = true
	_hint.text = text
	_hint.modulate.a = 1.0
	_hint.visible = true
	_hint_fade = dur


func _build_hint() -> void:
	_hint = Label.new()
	_hint.name = "HintLabel"
	_hint.visible = false
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -260.0
	_hint.offset_right = 260.0
	_hint.offset_top = -96.0
	_hint.offset_bottom = -64.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 0.9))
	add_child(_hint)
