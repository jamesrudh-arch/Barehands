extends Node
const CLS_Enemy := preload("res://scripts/enemy.gd")
## B30: THE DRUNKEN CHAIN - the last combat discipline reads complete:
## the SWAY (an off-axis roll through idle/walk nobody can read twice,
## measured, gone under brawler), the SLIP (a seeded fifth of unguarded
## strikes go through smoke - no damage, no stun, the attacker eats the
## parry stagger), the wide drunken PARRY (1.5x window), and the SPIN
## HEAVY (the tipsy whirl: the backfist arrives from the wrong side and
## the flanks pay for standing behind a drunk).
## Run: godot --headless --path . res://tests/smoke_drunk.tscn

var _fails := 0
var _checks := 0
var _main: Node
var _player: CharacterBody3D
var _dummy: CharacterBody3D
var _thug: CharacterBody3D
var _sweep_hits := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("DRUNK FAIL: ", what)
	else:
		print("DRUNK ok: ", what)


func _physics_seconds(t: float) -> void:
	var frames := int(round(t * 60.0))
	for i in frames:
		await get_tree().physics_frame


func _ready() -> void:
	Heat.test_pin_eyes = 1
	Settings.set_value("first_run_done", true)
	Settings.set_value("dynamic_events", false)
	for id in Trust.FRIENDS:
		Trust.add(id, -100.0, "suite")
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	_player = _main.get_node("Player") as CharacterBody3D
	_dummy = _main.get_node("Dummy") as CharacterBody3D
	_thug = _main.get_node("Thug") as CharacterBody3D
	Styles.unlock_all_for_test()
	Styles.switch_to("drunken")
	_player.hit_landed.connect(func(k: String, _d: int) -> void:
		if k == "spin_sweep":
			_sweep_hits += 1)
	await get_tree().create_timer(1.5).timeout

	# 1. THE SWAY: the drunk never stands where you look
	_player.global_position = Vector3(0.0, 0.05, 6.0)
	_player.velocity = Vector3.ZERO
	await _physics_seconds(1.4)
	var sway := 0.0
	for i in 30:
		await get_tree().physics_frame
		sway = maxf(sway, absf(float(_player.get("_body").rotation.z)))
	_check(sway > 0.03,
			"the drunken stance sways (peak roll %.3f rad)" % sway)
	Styles.switch_to("brawler")
	await _physics_seconds(1.2)
	var square := 0.0
	for i in 24:
		await get_tree().physics_frame
		square = maxf(square, absf(float(_player.get("_body").rotation.z)))
	_check(square < 0.01,
			"the brawler stands square (peak roll %.3f rad)" % square)
	Styles.switch_to("drunken")

	# 2. THE SLIP: a seeded fifth goes through smoke, and the miss pays
	(_player.get("_drunk_rng") as RandomNumberGenerator).seed = 13
	var slips := 0
	var taken := 0
	for i in 40:
		if i % 8 == 0:
			Composure.reset()
			_player.state = _player.State.GROUND
			_player.global_position = Vector3(0.0, 0.05, 6.0)
		var r: String = _player.take_hit(Vector3(1.0, 0.0, 0.0), _thug)
		if r == "parried":
			slips += 1
			# synchronously, same frame: the attacker wears the stagger,
			# the drunk wears no stun
			if not _staggered_seen \
					and int(_thug.get("state")) == CLS_Enemy.State.STAGGER:
				_staggered_seen = true
				_unstunned_seen = int(_player.get("state")) == 0 \
						and float(_player.get("_hitstun_until")) \
						<= float(_player.get("_t"))
		else:
			taken += 1
	_check(slips >= 4 and slips <= 18,
			"the slip takes its seeded fifth (%d slips / 40 strikes)" % slips)
	_check(taken + slips == 40,
			"every strike resolves one way or the other (%d slips, %d taken)" % [slips, taken])
	_check(_staggered_seen, "a slip staggers the attacker (the whiff pays)")
	_check(_unstunned_seen, "a slip leaves the drunk unstunned on his feet")

	# 3. THE WIDE PARRY: the drunk reads punches like a prophecy
	_check(Styles.parry_mult() == 1.5,
			"the drunken parry window is 1.5x (%.1f)" % Styles.parry_mult())
	_check(absf(float(_player.call("_parry_window")) - 0.45) < 0.001,
			"the live parry window is 450 ms under drunken (%.3f)"
			% float(_player.call("_parry_window")))

	# 4. THE SPIN HEAVY: the flanks pay for standing behind a drunk
	Styles.switch_to("drunken")
	_dummy.set("hp", 5)
	_dummy.global_position = Vector3(1.0, 0.05, 6.0)
	_dummy.velocity = Vector3.ZERO
	_thug.set("hp", 5)
	_thug.global_position = Vector3(-1.3, 0.05, 6.15)  # BEHIND the swing
	_thug.velocity = Vector3.ZERO
	_player.global_position = Vector3(0.0, 0.05, 6.05)
	_player.velocity = Vector3.ZERO
	(_player.get("_body") as Node3D).rotation.y = -PI / 2.0  # face east
	_player.state = _player.State.GROUND
	var yaw0: float = (_player.get("_body") as Node3D).rotation.y
	_player.call("_start_punch", 1, true)
	var spun := false
	for i in 90:
		await get_tree().physics_frame
		# hold the enemies where the leg planted them (their AI may
		# otherwise close in and muddy the geometry)
		_dummy.global_position = Vector3(1.0, 0.05, 6.0)
		_thug.global_position = Vector3(-1.3, 0.05, 6.15)
		var dy := absf((_player.get("_body") as Node3D).rotation.y - yaw0)
		if dy > 2.0:
			spun = true
	_check(str(_player.get("_punch_variant")) == "spin",
			"the drunken heavy takes the spin variant")
	_check(spun, "the whirl carries the whole body round")
	_check(int(_thug.get("hp")) < 5,
			"the flank EATS the far side of the whirl (hp %d)" % int(_thug.get("hp")))
	_check(int(_dummy.get("hp")) < 5,
			"the front target still pays full price (hp %d)" % int(_dummy.get("hp")))
	_check(_sweep_hits >= 1, "the sweep lands as its own style move")

	# 5. the brawler contrast: the same heavy, no whirl, the flank is safe
	Styles.switch_to("brawler")
	_dummy.set("hp", 5)
	_dummy.global_position = Vector3(1.0, 0.05, 6.0)
	_thug.set("hp", 5)
	_thug.global_position = Vector3(-1.3, 0.05, 6.15)
	_player.global_position = Vector3(0.0, 0.05, 6.05)
	_player.velocity = Vector3.ZERO
	(_player.get("_body") as Node3D).rotation.y = -PI / 2.0
	_player.state = _player.State.GROUND
	var yaw_b: float = (_player.get("_body") as Node3D).rotation.y
	_player.call("_start_punch", 1, true)
	var spun_b := false
	for i in 90:
		await get_tree().physics_frame
		_dummy.global_position = Vector3(1.0, 0.05, 6.0)
		_thug.global_position = Vector3(-1.3, 0.05, 6.15)
		if absf((_player.get("_body") as Node3D).rotation.y - yaw_b) > 2.0:
			spun_b = true
	_check(not spun_b, "the brawler's heavy is honest - no whirl")
	_check(int(_thug.get("hp")) == 5,
			"the flank is safe from a brawler (hp %d)" % int(_thug.get("hp")))
	_check(int(_dummy.get("hp")) < 5,
			"but the front target still pays (hp %d)" % int(_dummy.get("hp")))

	_finish()


var _staggered_seen := false
var _unstunned_seen := false


func _finish() -> void:
	await get_tree().create_timer(0.5).timeout
	print("DRUNK RESULT: %d checks, %d fails" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
