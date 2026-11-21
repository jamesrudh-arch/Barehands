extends Node
const CLS_MapData := preload("res://scripts/map_data.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")

## B18 Part 6C suite: NEVER LOST. Boots the real street with a fresh
## user dir (intro not done), then walks the whole guided intro: the
## hero wakes in the apartment, the door prompt + contextual INTERACT
## appear at the door, the door opens to the street, the objective
## text updates at each step, a street path exists to the noodle shop,
## reaching it finishes the intro, the sonar ping rate shortens with
## distance, the 20-second hint fires, and no duplicate button set
## exists.

var _fails := 0
var _checks := 0
var _main: Node
var _guide: Node
var _hero: Node3D
var _apartment: Node
var _hud: Node


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("GUIDE FAIL: ", what)
	else:
		print("GUIDE ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.25)
		await get_tree().create_timer(step).timeout
		left -= step


func _ready() -> void:
	# fresh dir: first_run_done FALSE and intro_done unset -> the REAL
	# first-run path: the picker shows, we pick a movement card, the
	# hero wakes in the apartment. (Every other suite sets
	# first_run_done and boots on the street.)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	var fr := _main.get_node_or_null("FirstRun")
	if fr:
		var cards := fr.find_children("Move_*", "Button", true, false)
		if cards.size() >= 2:
			(cards[1] as Button).pressed.emit()
	await get_tree().process_frame
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await _wait_s(1.0)
	_guide = get_tree().get_first_node_in_group("guide")
	_hero = get_tree().get_first_node_in_group("player") as Node3D
	_hud = get_tree().get_first_node_in_group("hud_buttons")
	for n in get_tree().get_nodes_in_group("door_prompt"):
		if str(n.name).begins_with("Apartment"):
			_apartment = n

	_intro_lives()
	await _hint_fires()
	await _door_flow()
	await _orb_checks()
	_sonar()
	await _reach_dummy()
	_no_duplicates()

	if _fails == 0:
		print("GUIDE PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("GUIDE FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


## The intro is live: guide running, hero INSIDE the apartment, the
## objective text pointing at the door.
func _intro_lives() -> void:
	_check(_guide != null, "the guide exists in the scene")
	_check(_apartment != null, "the apartment (starting room) exists")
	if _guide == null or _hero == null:
		return
	_check(int(_guide.get("step")) == 0, "the intro starts at step 0")
	_check(absf(_hero.global_position.x - 780.0) < 6.0,
			"the hero wakes inside the apartment (x=%.1f)" % _hero.global_position.x)
	var nav: Dictionary = CLS_MapData.nav_target()
	_check(str(nav.get("text", "")).find("DOOR") >= 0,
			"the navigation target is the door ('%s')" % str(nav.get("text", "")))


## 20 s without progress -> the hint appears.
func _hint_fires() -> void:
	if _guide == null or _hud == null:
		_check(false, "guide/hud present for the hint test")
		return
	_guide.set("_hint_t", 19.9)
	await _wait_s(0.25)
	var label = _hud.get_node_or_null("HintLabel")
	_check(label != null and str(label.text) != "" and label.visible,
			"the no-progress hint appears ('%s')" % str(label.text if label else "?"))


## Walk to the door: prompt + contextual INTERACT appear; open it: the
## hero lands on the street and the objective updates.
func _door_flow() -> void:
	if _apartment == null or _hero == null:
		_check(false, "apartment/hero present for the door test")
		return
	# stand at the door (inside the room, in its zone)
	var door: Vector3 = _apartment.call("door_world_pos")
	_hero.global_position = door + Vector3(0, 0.02, 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(bool(_apartment.call("is_near")), "standing at the door registers")
	# the prompt is the OPEN Label3D child of the room; find by text
	var prompt_found := false
	for c in _apartment.get_children():
		if c is Label3D and str((c as Label3D).text) == "OPEN" \
				and (c as Label3D).visible:
			prompt_found = true
	_check(prompt_found, "the OPEN prompt shows at the door")
	# the contextual INTERACT button is live (apartment is a safehouse
	# consumer; the label refreshes at 10 Hz)
	await _wait_s(0.3)
	var grab = _hud._buttons.get("GrabBtn") if _hud else null
	_check(grab != null and grab.visible and str(grab.label) != "",
			"the contextual button shows at the door ('%s')" % str(grab.label if grab else "?"))
	# open it: swing + fade + teleport to the street
	_apartment.call("try_use", _hero)
	await _wait_s(2.2)
	_check(_hero.global_position.x < 100.0,
			"opening the door puts the hero on the street (x=%.1f)" % _hero.global_position.x)
	if _guide:
		_check(int(_guide.get("step")) == 2,
				"the objective advanced to the warm-up (step %d)" % int(_guide.get("step")))
	# a street path exists from the exit to the noodle shop
	var route: PackedVector2Array = CLS_MapData.route(
			Vector2(_hero.global_position.x, _hero.global_position.z),
			Vector2(-4.0, 8.2))
	_check(route.size() >= 2,
			"a street path exists from the exit to the noodle shop (%d nodes)" % route.size())


## B18.3 6C.4: the green guide orb - exists, leads along the route,
## waits when the hero stalls, arrives and bounces, and recalls.
func _orb_checks() -> void:
	var orb := get_tree().get_first_node_in_group("guide_orb") as Node3D
	_check(orb != null, "the guide orb exists")
	if orb == null or _hero == null:
		return
	await _wait_s(0.8)
	_check(orb.global_position.distance_to(_hero.global_position) < 12.0,
			"the orb stays near the hero (%.1f m)" % orb.global_position.distance_to(_hero.global_position))
	_check(int(orb.get("state")) in [0, 1, 2], "the orb has a live state")
	# the lead builds while the hero WALKS (a standing hero makes the
	# orb wait - that is the design); drive the stick through its own
	# test hook so the anti-drift loop keeps the value
	var stick := get_tree().get_first_node_in_group("stick")
	if stick and stick.has_method("debug_set_move"):
		stick.call("debug_set_move", Vector2(0, -0.8))
	await _wait_s(1.5)
	if stick and stick.has_method("debug_set_move"):
		stick.call("debug_set_move", Vector2.ZERO)
	await _wait_s(0.3)
	var lead: float = float(orb.call("lead_now"))
	_check(lead > 2.0 and lead < 9.0,
			"the orb leads the walking hero (%.1f m)" % lead)
	# a stalled hero makes it wait
	(_hero as CharacterBody3D).velocity = Vector3.ZERO
	await _wait_s(1.6)
	_check(int(orb.get("state")) == 1,
			"a stopped hero makes the orb wait (state %d)" % int(orb.get("state")))
	(_hero as CharacterBody3D).velocity = Vector3(3, 0, 0)
	await _wait_s(0.5)
	# recall brings the progress back to the hero
	orb.call("recall")
	await get_tree().physics_frame
	_check(absf(float(orb.call("lead_now"))) < 3.0, "recall returns the orb to the hero")
	(_hero as CharacterBody3D).velocity = Vector3.ZERO


## The sonar ping interval shortens as the distance drops.
func _sonar() -> void:
	if _guide == null:
		_check(false, "guide present for the sonar test")
		return
	var far: float = _guide.call("ping_interval", 40.0)
	var near: float = _guide.call("ping_interval", 5.0)
	_check(near < far,
			"the sonar pings faster when closer (%.2f s near vs %.2f s far)" % [near, far])
	_check(bool(Settings.value("sonar_on")), "the sonar is on by default")


## Reach the training dummy: the intro completes and persists.
func _reach_dummy() -> void:
	if _hero == null:
		return
	_hero.global_position = Vector3(-1.3, 0.02, -4.5)
	await _wait_s(0.5)
	_check(_guide != null and int(_guide.get("step")) == 3,
			"reaching the dummy finishes the intro")
	_check(Settings.hint_done("intro_done"), "the finished intro persists")


## BUG 6 guard: exactly one button per name - never two sets.
func _no_duplicates() -> void:
	if _hud == null:
		_check(false, "hud present for the duplicate audit")
		return
	var names := {}
	var dupes: Array[String] = []
	for c in _hud.get_children():
		if c.has_signal("down"):
			if names.has(c.name):
				dupes.append(c.name)
			names[c.name] = true
	_check(dupes.is_empty(), "no duplicate button sets (found %s)"
			% (", ".join(dupes) if not dupes.is_empty() else "none"))
