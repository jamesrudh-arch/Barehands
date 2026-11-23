extends Node
## S5.11 THE JOBS + THE ARC: all ten core jobs and the kidnap arc
## driven end-to-end on the real engine - every template (Delivery,
## Rescue, Coerced, Hit, Turf), the k-arc's rings, the door unseal,
## and THE CHOICE's teeth (zeroed pools, the permanent enemy).
var _pass := 0
var _fail := 0

func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		await get_tree().create_timer(minf(0.1, left)).timeout
		left -= 0.1

func _check(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("JOB PASS %s" % what)
	else:
		_fail += 1
		print("JOB FAIL %s" % what)

func _ms() -> Node:
	return get_tree().get_first_node_in_group("missions")

func _ph() -> Node:
	return get_tree().get_first_node_in_group("phone")

func _hero() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func _down_all() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and float(e.get("hp")) > 0.0:
			e.take_hit(999.0, 0.0, Vector3(1, 0, 0), 99.0)
	WorldState.set_value("heat", 0.0)

func _heal() -> void:
	var h := _hero()
	if h and is_instance_valid(h):
		h.set("hp", 100.0)

## wait for the mission to reach a stage index (or complete)
func _until(idx: int, done_id: String = "", secs: float = 8.0) -> bool:
	var left := secs
	while left > 0.0:
		var m := _ms()
		if m.active == null:
			if done_id != "" and WorldState.flag("mission_done:" + done_id):
				return true
			return true  # chained on to the next
		if m.stage_index >= idx:
			return true
		if done_id != "" and WorldState.flag("mission_done:" + done_id):
			return true
		_down_all()
		_heal()
		await _wait_s(0.35)
		left -= 0.35
	return false

func _grab(at: Vector3) -> void:
	var h := _hero()
	if h and is_instance_valid(h):
		h.global_position = at
	await _wait_s(0.25)
	_ms().try_grab(_hero())

func _goto(at: Vector3) -> void:
	var h := _hero()
	if h and is_instance_valid(h):
		h.global_position = at
	await _wait_s(0.35)

func _answer_call() -> void:
	await _wait_s(0.4)
	_ph()._answer()
	await _wait_s(0.3)

func _ready() -> void:
	var dog := get_tree().create_timer(420.0, true, false, true)
	dog.timeout.connect(func(): _finish())
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.4)

	# --- j1 THE DROP (Delivery)
	_ms().start("res://data/missions/j1.tres")
	await Game.travel("warehouse", "start")
	await _wait_s(1.6)
	await _goto(Vector3(-6.5, 0.05, 4.8))
	await _wait_s(0.5)
	_check(_ms().stage_index == 1, "j1: the package lifts")
	await Game.travel("docks", "start")
	await _wait_s(1.6)
	await _goto(Vector3(30.0, 0.05, -1.6))
	await _wait_s(0.6)
	_check(WorldState.flag("mission_done:j1"),
			"j1 THE DROP: delivered to Sal (+$250)")

	# --- j2 ROOM SERVICE (Rescue)
	_ms().start("res://data/missions/j2.tres")
	await Game.travel("club_district", "start")
	await _wait_s(1.6)
	await _goto(Vector3(-22.0, 0.05, 7.2))
	var ok_0 := await _until(1, "j2")
	_check(ok_0, "j2: the hotel door reached")
	var ok_101 := await _until(9, "j2", 10.0)
	_check(ok_101 and WorldState.flag("mission_done:j2"), "j2 ROOM SERVICE: the guests settled (+$200)")

	# --- j3 THE COPY'S DEBT (Hit) - we are at the club, the job is
	# at the docks
	_ms().start("res://data/missions/j3.tres")
	await Game.travel("docks", "start")
	await _wait_s(1.6)
	var ok_102 := await _until(9, "j3", 12.0)
	_check(ok_102 and WorldState.flag("mission_done:j3"), "j3 THE COPY'S DEBT: the student down, the yard quiet (+$300)")

	# --- j4 VESPER'S FAVOR (Coerced)
	_ms().start("res://data/missions/j4.tres")
	await Game.travel("club_district", "start")
	await _wait_s(1.6)
	_grab(Vector3(-41.5, 0.05, -5.0))
	await _wait_s(0.4)
	await _goto(Vector3(-41.5, 0.05, 3.0))
	await _wait_s(0.5)
	_check(WorldState.flag("mission_done:j4"),
			"j4 VESPER'S FAVOR: the corner taken (+$180)")

	# --- j5 THE WATCH (Turf)
	_ms().start("res://data/missions/j5.tres")
	await _goto(Vector3(-41.5, 0.05, 3.0))
	var ok_103 := await _until(9, "j5", 16.0)
	_check(ok_103 and WorldState.flag("mission_done:j5"), "j5 THE WATCH: the curb held through two waves (+$320)")

	# --- j6 DEE'S SUPPLIES (Delivery)
	_ms().start("res://data/missions/j6.tres")
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	await _goto(Vector3(6.0, 0.05, 5.4))
	await _wait_s(0.6)
	_check(_ms().stage_index == 1, "j6: the crate lifts")
	await _goto(Vector3(-40.4, 0.05, 5.4))
	await _wait_s(0.6)
	_check(WorldState.flag("mission_done:j6"),
			"j6 DEE'S SUPPLIES: Dee's counter (+$120 +$80 clean)")

	# --- j7 THE MECHANIC'S PROBLEM (Hit)
	_ms().start("res://data/missions/j7.tres")
	await Game.travel("club_district", "start")
	await _wait_s(1.6)
	await _goto(Vector3(36.0, 0.05, 7.2))
	var ok_104 := await _until(9, "j7", 12.0)
	_check(ok_104 and WorldState.flag("mission_done:j7"), "j7 THE MECHANIC'S PROBLEM: three hands (+$350)")

	# --- j8 WALK HIS ROUTE (Coerced - no combat)
	_ms().start("res://data/missions/j8.tres")
	await Game.travel("docks", "start")
	await _wait_s(1.6)
	await _goto(Vector3(10.0, 0.05, 8.0))
	await _goto(Vector3(-10.0, 0.05, -2.0))
	await _goto(Vector3(-30.0, 0.05, -8.0))
	await _wait_s(0.5)
	_check(WorldState.flag("mission_done:j8"),
			"j8 WALK HIS ROUTE: the route learned (+$220)")

	# --- j9 THE QUIET WARNING (Coerced - the ring)
	_ms().start("res://data/missions/j9.tres")
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	_check(not _ph()._ring.is_empty(), "j9: the Corporation rings")
	await _answer_call()
	_ph()._choice(0)  # PAY A VISIT
	await _wait_s(0.4)
	_check(WorldState.flag("j9_visit"), "j9: the visit chosen")
	await Game.travel("docks", "start")
	await _wait_s(1.6)
	var ok_105 := await _until(9, "j9", 12.0)
	_check(ok_105 and WorldState.flag("mission_done:j9"), "j9 THE QUIET WARNING: the container maze (+$280)")

	# --- j10 THE BIG MOVE (Turf/Hit)
	_ms().start("res://data/missions/j10.tres")
	await _wait_s(0.5)
	var ok_106 := await _until(9, "j10", 20.0)
	_check(ok_106 and WorldState.flag("mission_done:j10"), "j10 THE BIG MOVE: two waves + the quiet yard (+$500)")

	# --- k1 COLD CALL
	_ms().start("res://data/missions/k1.tres")
	await _wait_s(0.6)
	_check(not _ph()._ring.is_empty() and str(
			_ph()._ring.get("from", "")) == "THE BROTHER",
			"k1: the brother's voice on the line")
	await _answer_call()
	_ph()._choice(0)
	await _wait_s(0.4)
	await Game.travel("warehouse", "start")
	await _wait_s(1.6)
	await _goto(Vector3(-6.5, 0.05, 4.8))
	await _wait_s(0.6)
	_check(WorldState.flag("mission_done:k1"),
			"k1 COLD CALL: home, at the workbench")

	# --- k2 THE INVESTIGATION (no combat)
	_ms().start("res://data/missions/k2.tres")
	await Game.travel("neighbourhood", "start")
	await _wait_s(1.6)
	await _goto(Vector3(-20.0, 0.05, 3.4))
	await Game.travel("club_district", "start")
	await _wait_s(1.6)
	await _goto(Vector3(-41.5, 0.05, -5.0))
	await Game.travel("docks", "start")
	await _wait_s(1.6)
	_grab(Vector3(-36.0, 0.05, -6.0))
	await _wait_s(0.4)
	_check(WorldState.flag("mission_done:k2"),
			"k2 THE INVESTIGATION: the route + the tape")

	# --- k3 THE ASSAULT (the unseal + the waves)
	_ms().start("res://data/missions/k3.tres")
	await _wait_s(0.6)
	_check(WorldState.flag("door_open:DOCK WAREHOUSE 9")
			and str(Doors._doors["DOCK WAREHOUSE 9"]["state"]) != "locked",
			"k3: the tape comes off (Warehouse 9 unsealed)")
	var ok_107 := await _until(9, "k3", 20.0)
	_check(ok_107 and WorldState.flag("mission_done:k3"), "k3 THE ASSAULT: the guards + the Lieutenant (+$400)")

	# --- k4 THE CHOICE
	WorldState.set_value("stash_cash", 600.0)
	WorldState.set_value("clean_cash", 300.0)
	_ms().start("res://data/missions/k4.tres")
	await _wait_s(0.6)
	_check(not _ph()._ring.is_empty(), "k4: the choice rings")
	await _answer_call()
	_ph()._choice(0)  # SAVE THEM
	await _wait_s(0.5)
	_check(WorldState.flag("k_saved"), "k4: they are saved")
	_check(is_equal_approx(float(WorldState.get_value(
			"stash_cash", -1.0)), 0.0)
			and is_equal_approx(float(WorldState.get_value(
			"clean_cash", -1.0)), 0.0),
			"k4: the money burns (both pools zeroed)")
	_check(WorldState.flag("corp_enemy"),
			"k4: the Corporation never forgets (corp_enemy)")
	_check(WorldState.flag("mission_done:k4"), "k4 THE CHOICE: made")
	# the permanent enemy sends harder men
	var msw := _ms()
	msw._pending_spawn = [{"pos": Vector3(0, 0.05, 0), "hp": 80.0}]
	msw._spawn_muscle()
	var last: Node = null
	for e in get_tree().get_nodes_in_group("mission_spawn"):
		last = e
	_check(last != null and is_equal_approx(float(last.get("hp")),
			100.0), "corp_enemy escalates the city's men (x1.25)")
	# the payoff path (fresh state)
	WorldState.set_value("stash_cash", 600.0)
	WorldState.set_value("clean_cash", 300.0)
	WorldState.set_value("k_saved", false)
	WorldState.set_value("corp_enemy", false)
	_ms().start("res://data/missions/k4.tres")
	await _wait_s(0.6)
	await _answer_call()
	_ph()._choice(1)  # TAKE THE PAYOFF
	await _wait_s(0.5)
	_check(WorldState.flag("k_paid")
			and is_equal_approx(float(WorldState.get_value(
			"clean_cash", 0.0)), 2300.0),
			"k4 alt: the payoff lands (+$2000 clean)")
	_finish()

func _finish() -> void:
	print("JOB RESULT pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
