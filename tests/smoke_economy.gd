extends Node
## S5.5 ECONOMY SUITE: the pools (dirty/clean, the surcharge), the
## vendors (Old Dee's bowl, Tony's box, Vesper's laundering + cap),
## the debt split, the quick-pay chip, the overnight pressure.
var _pass := 0
var _fail := 0

func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("ECON PASS %s" % what)
	else:
		_fail += 1
		print("ECON FAIL %s" % what)

func _market() -> Node:
	for m in get_tree().get_nodes_in_group("market"):
		return m
	return null

func _ready() -> void:
	var dog := get_tree().create_timer(140.0)
	dog.timeout.connect(func(): _finish())
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.2)
	# 1) THE DEBT SPLIT (the bible's five grand)
	_check(is_equal_approx(float(WorldState.get_value("debt", 0.0)),
			5000.0), "debt starts at the tuned five grand")
	_check(is_equal_approx(float(WorldState.get_value(
			"debt_family", 0.0)), 3500.0)
			and is_equal_approx(float(WorldState.get_value(
			"debt_corp", 0.0)), 1500.0),
			"the split: family 3500 / corp 1500")
	var mkt := _market()
	_check(mkt != null, "the market rides Game")
	# 2) pay(): clean first, dirty at the surcharge
	WorldState.set_value("clean_cash", 50.0)
	WorldState.set_value("stash_cash", 100.0)
	var res: Dictionary = mkt.pay(60.0)
	_check(res["ok"] and is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 0.0)
			and is_equal_approx(float(WorldState.get_value(
			"stash_cash", 0.0)), 87.5),
			"pay 60: clean 50 + dirty 10 x1.25 = 12.5 (stash 87.5)")
	res = mkt.pay(1000.0)
	_check(not res["ok"], "empty pockets decline")
	WorldState.set_value("stash_cash", 100.0)
	WorldState.set_value("clean_cash", 0.0)
	# 3) NOODLES at Old Dee (neighbourhood)
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.2)
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	hero.set("hp", 20.0)
	hero.global_position = Vector3(-40.4, 0.05, 5.4)
	await _wait_s(0.2)
	_check(mkt.try_grab(hero), "the bowl answers the grab")
	_check(float(hero.get("hp")) >= float(hero.get("MAX_HP")) - 0.01,
			"the bowl heals to full (hp %.0f)" % float(hero.get("hp")))
	_check(is_equal_approx(float(WorldState.get_value("stash_cash",
			0.0)), 90.0), "noodles cost 8 dirty x1.25 = 10 (stash 90)")
	_check(mkt.try_grab(hero), "Dee still answers when full")
	_check(is_equal_approx(float(WorldState.get_value("stash_cash",
			0.0)), 90.0), "a full hero doesn't pay twice")
	# 4) TONY's box + VESPER's laundering (club)
	await Game.travel("club_district", "start")
	await _wait_s(1.2)
	hero = get_tree().get_first_node_in_group("player") as Node3D
	var gun := hero.get_node_or_null("Gun")
	_check(gun != null, "the pistol rides the hero")
	gun.set("reserve", 0)
	hero.global_position = Vector3(-35.5, 0.05, 5.0)
	await _wait_s(0.2)
	_check(mkt.try_grab(hero), "Tony answers the grab")
	_check(int(gun.get("reserve")) == 12, "a box of twelve (+12)")
	_check(is_equal_approx(float(WorldState.get_value("stash_cash",
			0.0)), 58.75), "the box cost 25 x1.25 (stash 58.75)")
	# 5) LAUNDERING: the cut, the cap, the window
	WorldState.set_value("stash_cash", 1000.0)
	hero.global_position = Vector3(-41.5, 0.05, -5.0)
	await _wait_s(0.2)
	_check(mkt.try_grab(hero), "Vesper answers the grab")
	_check(is_equal_approx(float(WorldState.get_value("clean_cash",
			0.0)), 480.0), "600 moved at 20%% cut = 480 clean")
	_check(is_equal_approx(float(WorldState.get_value("stash_cash",
			0.0)), 400.0), "stash 1000 - 600 = 400")
	_check(mkt.try_grab(hero), "the cap answers too")
	_check(is_equal_approx(float(WorldState.get_value("stash_cash",
			0.0)), 400.0), "the window cap holds at 600")
	# S5.8: the window opens on the BEAT, not a clock
	var wsx := get_tree().get_first_node_in_group("worldsim")
	wsx.advance_beat()
	WorldState.set_value("launder_cap", 600.0)  # deterministic
	await _wait_s(0.3)
	_check(mkt.try_grab(hero), "a new window answers")
	_check(is_equal_approx(float(WorldState.get_value("clean_cash",
			0.0)), 800.0) and is_equal_approx(float(
			WorldState.get_value("stash_cash", 0.0)), 0.0),
			"window reset: 400 more moved, stash empty")
	# 6) THE DEBT EATS CLEAN (the chip's law)
	WorldState.set_value("debt", 5000.0)
	_check(mkt.pay_debt(100.0), "the chip pays")
	_check(is_equal_approx(float(WorldState.get_value("debt", 0.0)),
			4900.0), "debt 5000 - 100 = 4900")
	_check(is_equal_approx(float(WorldState.get_value("clean_cash",
			0.0)), 700.0), "clean 800 - 100 = 700")
	WorldState.set_value("clean_cash", 0.0)
	_check(not mkt.pay_debt(100.0), "no clean, no chip")
	# 7) THE OVERNIGHT PRESSURE (the stand-in clock)
	WorldState.set_value("debt", 5000.0)
	WorldState.set_value("stash_cash", 1500.0)
	WorldState.set_value("heat", 0.0)
	mkt._overnight_pressure()
	_check(is_equal_approx(float(WorldState.get_value("debt", 0.0)),
			5025.0), "interest: 5000 +0.5%% = 5025")
	_check(is_equal_approx(float(WorldState.get_value("heat", 0.0)),
			0.3), "the full pocket gets noticed (+0.3 heat)")
	await _beat_checks()
	_finish()

func _beat_checks() -> void:
	# S5.8: the pressure + windows ride the beat, midnight costs more
	var ws := get_tree().get_first_node_in_group("worldsim")
	_check(ws != null, "the worldsim is up for the economy")
	if ws == null:
		return
	# the earlier sections leave the hero at the fence's dock -
	# come home to the street for Dee's counter
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.4)
	ws = get_tree().get_first_node_in_group("worldsim")
	WorldState.set_value("debt", 1000.0)
	WorldState.set_value("stash_cash", 0.0)
	ws.advance_beat()
	await _wait_s(0.4)
	_check(float(WorldState.get_value("debt", 0.0)) > 1000.0,
			"a beat ticks the interest (debt grew)")
	_check(is_equal_approx(
			float(WorldState.get_value("laundered_window", -1.0)),
			0.0), "a beat opens a fresh laundering window")
	var cap1 := float(WorldState.get_value("launder_cap", 0.0))
	_check(cap1 > 0.0, "the drifting cap re-rolled (%d)" % int(cap1))
	# the burn notice fires per beat now
	WorldState.set_value("stash_cash", 3000.0)
	WorldState.set_value("heat", 0.0)
	ws.advance_beat()
	await _wait_s(0.4)
	_check(float(WorldState.get_value("heat", 0.0)) > 0.0,
			"a full pocket gets noticed each beat")
	# the night premium: MIDNIGHT (beat % 3 == 1) costs +10%
	ws.set_weather("clear")
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var mkt2: Node = null
	for m in get_tree().get_nodes_in_group("market"):
		mkt2 = m
	var mkt: Node = null
	for m in get_tree().get_nodes_in_group("market"):
		mkt = m
	hero.global_position = Vector3(-40.4, 0.05, 5.4)
	hero.set("hp", 40.0)
	while int(ws.beat()) % 3 != 1:
		ws.advance_beat()
		await _wait_s(0.2)
	WorldState.set_value("clean_cash", 200.0)
	mkt2.try_grab(hero)
	await _wait_s(0.3)
	_check(is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 191.2),
			"MIDNIGHT: the bowl costs $8.80 (8 x 1.10)")
	while int(ws.beat()) % 3 != 0:
		ws.advance_beat()
		await _wait_s(0.2)
	hero.set("hp", 40.0)
	WorldState.set_value("clean_cash", 200.0)
	mkt2.try_grab(hero)
	await _wait_s(0.3)
	_check(is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 192.0),
			"DUSK: the bowl is $8 again (no premium)")

func _finish() -> void:
	print("ECON RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
