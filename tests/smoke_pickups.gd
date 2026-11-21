extends Node
const CLS_Pickup := preload("res://scripts/pickup.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")

## B18.3 PART 6D suite: PICKUPS AND WEAPONS. Boots the real street,
## then checks the placement contract (the room bottle, the street
## weapons and items), the [B] prompt near a pickup, the context verb,
## pickup-by-grab equipping through the Weapons layer (HUD chip +
## durability), the break at zero, and the cash item.

var _fails := 0
var _checks := 0
var _main: Node
var _hero: Node3D
var _hud: Node


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("PICKUP FAIL: ", what)
	else:
		print("PICKUP ok: ", what)


func _wait_s(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.25)
		await get_tree().create_timer(step).timeout
		left -= step


func _nearest_pickup() -> Node:
	var best: Node = null
	var best_d := INF
	for pk in get_tree().get_nodes_in_group("pickup"):
		if pk is Node3D and _hero:
			var d: float = (pk as Node3D).global_position.distance_to(_hero.global_position)
			if d < best_d:
				best_d = d
				best = pk
	return best


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	await _wait_s(1.2)
	_hero = get_tree().get_first_node_in_group("player") as Node3D
	_hud = get_tree().get_first_node_in_group("hud_buttons")

	_placement()
	await _prompt_and_pickup()
	_durability_and_break()
	await _cash_item()

	if _fails == 0:
		print("PICKUP PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("PICKUP FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)


## The placement contract: the room bottle, the street pipe at its
## historic spot, a bat, a plank, bottles by the noodle front, items.
func _placement() -> void:
	var kinds := {}
	for pk in get_tree().get_nodes_in_group("pickup"):
		var k := str((pk as Node).get_meta("pickup_kind", "?"))
		kinds[k] = int(kinds.get(k, 0)) + 1
	for want in ["bottle", "pipe", "bat", "plank", "chair_leg",
			"cash", "health", "painkillers", "key", "burner"]:
		_check(int(kinds.get(want, 0)) >= 1, "a %s is placed (%d)" % [want, int(kinds.get(want, 0))])
	var room_bottle := false
	for pk in get_tree().get_nodes_in_group("pickup"):
		if pk is Node3D and str((pk as Node).get_meta("pickup_kind", "")) == "bottle" \
				and absf((pk as Node3D).global_position.x - 780.0) < 6.0:
			room_bottle = true
	_check(room_bottle, "the starting room holds a bottle by the door")


## Stand at the pipe: prompt shows, the context verb is PICK UP, the
## grab chain picks it up, the Weapons HUD chip appears.
func _prompt_and_pickup() -> void:
	if _hero == null:
		_check(false, "hero alive for the pickup test")
		return
	var pipe: Node = null
	for pk in get_tree().get_nodes_in_group("pickup"):
		if str((pk as Node).get_meta("pickup_kind", "")) == "pipe":
			pipe = pk
			break
	_check(pipe != null, "the street pipe exists")
	if pipe == null:
		return
	_hero.global_position = (pipe as Node3D).global_position + Vector3(0.6, 0.02, 0.6)
	await _wait_s(0.4)
	_check(bool(pipe.call("is_near")), "standing at the pipe registers")
	var prompt_found := false
	for c in pipe.get_children():
		if c is Label3D and (c as Label3D).visible \
				and str((c as Label3D).text).find("PICK UP") >= 0:
			prompt_found = true
	_check(prompt_found, "the [B] PICK UP prompt shows near the pipe")
	_check(str(_hero.call("context_action")) == "PICK UP",
			"the context verb is PICK UP (%s)" % str(_hero.call("context_action")))
	var hud_btn = _hud._buttons.get("FightB") if _hud else null
	if hud_btn:
		_check(str(hud_btn.sub) == "PICK UP",
				"the B button wears the verb (%s)" % str(hud_btn.sub))
	# the grab chain picks it up
	_hero.call("_try_grab_action")
	await _wait_s(0.3)
	_check(Weapons.is_armed() and Weapons.weapon_name() == "LEAD PIPE",
			"the pipe equips through Weapons (%s)" % Weapons.weapon_name())
	_check(bool(_hero.get("has_pipe")), "the hero holds the pipe move set")
	_check(not is_instance_valid(pipe), "the pickup is gone after the take")
	var chip := Weapons.get("_chip") as Control
	_check(chip != null and chip.visible, "the weapon HUD chip is visible")


## Durability counts down on landed hits; zero breaks the weapon.
func _durability_and_break() -> void:
	if not Weapons.is_armed():
		_check(false, "weapon armed for the durability test")
		return
	var d0 := Weapons.durability
	Fx.hit_landed.emit("jab", _hero.global_position if _hero else Vector3.ZERO)
	Fx.hit_landed.emit("cross", Vector3.ZERO)
	_check(Weapons.durability == d0 - 2,
			"landed hits cost durability (%d -> %d)" % [d0, Weapons.durability])
	Fx.hit_landed.emit("player_hit", Vector3.ZERO)
	_check(Weapons.durability == d0 - 2, "taking a hit costs nothing")
	while Weapons.is_armed():
		Fx.hit_landed.emit("jab", Vector3.ZERO)
	_check(not Weapons.is_armed() and not bool(_hero.get("has_pipe")),
			"the weapon breaks at zero and the hands are bare again")


## The cash item earns into the wallet.
func _cash_item() -> void:
	if _hero == null:
		return
	var wallet0 := Wallet.total()
	var cash := CLS_Pickup.new()
	cash.setup("cash", 40)
	_main.add_child(cash)
	cash.global_position = _hero.global_position + Vector3(0.4, 0.0, 0.4)
	await _wait_s(0.4)
	cash.call("try_use", _hero)
	await _wait_s(0.3)
	_check(Wallet.total() >= wallet0 + 40,
			"the cash pickup earns into the wallet (%d -> %d)" % [wallet0, Wallet.total()])
