extends Node
## Headless smoke test for Series-2 Phase 6: the city remembers. District
## math, reputation from violence and stylish wins, hostile districts with
## muscle, nickname graffiti, witness memories, shopkeeper pricing and
## greetings, the district toast, and persistence. Not part of the game.

var _main: Node3D
var _player: CharacterBody3D
var _style: Control
var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("SMOKE FAIL: ", what)
	else:
		print("SMOKE ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)  # isolated user dir: no first-run picker
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	_player = _main.get_node("Player") as CharacterBody3D
	_style = get_tree().get_first_node_in_group("style") as Control
	Wallet.call("reset_for_test")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_districts()
	await _hostility()
	_graffiti()
	await _toast()
	_shopkeep()
	await _persist()
	_finish()


func _districts() -> void:
	# batch 8: one block = one district; the loaded block answers
	_check(Blocks.current() == "riverside", "the home block loads first")
	City.set_current_district("market")
	_check(City.district_now() == "market", "the walk switches districts")
	_check(City.district_at(Vector3(9, 0, 0)) == "market",
			"district_at answers the loaded block, not the x band")
	City.on_violence("knockdown", Vector3(0, 0, 0))
	_check(absf(City.rep["market"] + 8.0) < 0.01, "knockdown costs 8 rep in market (%.1f)" % City.rep["market"])
	_check(City.rep["riverside"] == 0.0, "other districts untouched")
	_check(City.witnessed["market"].size() == 1, "a witness remembers the event")
	City.on_stylish_win(Vector3(0, 0, 0), "counter")
	_check(absf(City.rep["market"] - -1.0) < 0.01, "stylish win +7 rep (rep %.1f)" % City.rep["market"])


func _hostility() -> void:
	City.set_current_district("riverside")
	# grind riverside down to hostile
	for i in 14:
		City.on_violence("knockdown", Vector3(-9, 0, 0))
	_check(City.hostile["riverside"], "riverside turns hostile after repeated brawls")
	_check(City.mood_of("riverside") == "hostile", "mood reads hostile")
	# standing there summons the district's muscle
	_player.global_position = Vector3(-9.0, 0.02, 0.0)
	await _wait(1.2)
	var muscle := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.kind == 1:
			muscle += 1
	_check(muscle >= 2, "hostile district keeps brawlers on you (%d)" % muscle)
	# leaving calms it; the muscle stands down (the walk, not the x band)
	City.set_current_district("market")
	await _wait(1.2)
	var still: int = City.get("_muscle").size()
	_check(still == 0, "muscle stands down when you leave (%d)" % still)
	# good will buys the district back
	City.add_rep("riverside", 70.0)
	_check(not City.hostile["riverside"], "good will buys the district back")


func _graffiti() -> void:
	City.add_rep("foundry", 40.0)
	var texts := City.graffiti_texts()
	_check(texts.has("THE NEW HANDS WAS HERE"), "nickname graffiti at rep 40 (%s)" % str(texts))
	City.add_rep("foundry", 40.0)
	texts = City.graffiti_texts()
	_check(texts.has("THE NEW HANDS RUNS THE FOUNDRY"), "bigger tag at rep 80 (%s)" % str(texts))
	var labels := 0
	for g in get_tree().root.find_children("*", "Label3D", true, false):
		labels += 1
	_check(labels >= 1, "graffiti is a Label3D on a wall (%d)" % labels)


func _toast() -> void:
	_player.global_position = Vector3(0.0, 0.02, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var toast: Label = _style.get_node_or_null("ToastLabel")
	_check(toast != null, "toast label exists")
	City.set_current_district("riverside")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(toast and toast.text.contains("RIVERSIDE"), "crossing into a block toasts (%s)" % toast.text)
	_check(toast.text.to_lower().contains("wary") or toast.text.to_lower().contains("hostile")
			or toast.text.to_lower().contains("indifferent") or toast.text.to_lower().contains("friendly"),
			"toast carries the mood (%s)" % toast.text)


func _shopkeep() -> void:
	City.set_current_district("market")
	# prices: friendly district discounts, hostile markups, heat premium
	City.rep["market"] = 50.0
	Heat.heat = 0.0
	var m_friendly: float = City.price_mult(Vector3(0, 0, 0))
	_check(absf(m_friendly - 0.85) < 0.01, "high rep prices at 0.85x (%.2f)" % m_friendly)
	City.rep["market"] = -40.0
	var m_wary: float = City.price_mult(Vector3(0, 0, 0))
	_check(absf(m_wary - 1.15) < 0.01, "bad rep prices at 1.15x (%.2f)" % m_wary)
	Heat.heat = 4.5
	var m_hot: float = City.price_mult(Vector3(0, 0, 0))
	_check(absf(m_hot - 1.25) < 0.01, "heat adds 10%% (%.2f)" % m_hot)
	Heat.heat = 0.0
	# greetings by reputation, with a witnessed memory
	City.rep["market"] = 45.0
	City.remember("market", "the counter in the market")
	var g: String = City.greeting(Vector3(0, 0, 0))
	_check("friend prices" in g.to_lower(), "high rep greets as a friend (%s)" % g)
	_check("they say" in g.to_lower(), "the shopkeeper recalls what witnesses saw (%s)" % g)
	City.rep["market"] = -60.0
	City.hostile["market"] = true
	g = City.greeting(Vector3(0, 0, 0))
	_check("not wanted" in g.to_lower(), "hostile district greets coldly (%s)" % g)
	City.hostile["market"] = false
	City.rep["market"] = 0.0


func _persist() -> void:
	City.add_rep("foundry", 10.0, "a memory to keep")
	City.nickname = "Ledger Hands"
	SaveGame.save_all()
	City.rep["foundry"] = 0.0
	City.nickname = "The New Hands"
	City.witnessed["foundry"] = []
	SaveGame.load_all()
	_check(absf(City.rep["foundry"] - 90.0) < 0.01, "rep persists (%.1f)" % City.rep["foundry"])
	_check(City.nickname == "Ledger Hands", "nickname persists (%s)" % City.nickname)
	_check(City.witnessed["foundry"].size() >= 1, "witnessed memories persist")


func _finish() -> void:
	if _fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL (%d problems)" % _fails)
		get_tree().quit(1)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
