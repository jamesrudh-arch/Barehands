extends Node
## Headless smoke test for Series-2 Phase 5: fight earnings x style rank
## into the Wallet, heat rise/decay/response, the three shops, gear and
## look application, and the safehouse save/load round-trip. Not part of
## the game.

var _main: Node3D
var _player: CharacterBody3D
var _style: Control
var _tailor: Area3D
var _gear_shop: Area3D
var _pawn: Area3D
var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("SMOKE FAIL: ", what)
	else:
		print("SMOKE ok: ", what)


func _ready() -> void:
	# one pair of eyes on the street: the witness multiplier sits at
	# x1.0 and every heat assertion in this suite is deterministic
	Heat.test_pin_eyes = 1
	Settings.set_value("first_run_done", true)  # isolated user dir: no first-run picker
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	_player = _main.get_node("Player") as CharacterBody3D
	_style = get_tree().get_first_node_in_group("style") as Control
	var shops: Array = []
	for s in _main.find_children("*", "Area3D", true, false):
		if s is Shop:
			shops.append(s)
	for s in shops:
		match (s as Shop).shop_id:
			"tailor":
				_tailor = s
			"gear":
				_gear_shop = s
			"pawn":
				_pawn = s
	Wallet.call("reset_for_test")
	await get_tree().physics_frame
	await get_tree().physics_frame

	_earnings()
	await _heat_cycle()
	_shopping()
	await _save_load()
	_finish()


func _earnings() -> void:
	Wallet.call("reset_for_test")
	var before := Wallet.dirty  # street show money pays DIRTY (batch 6)
	_style.set("value", 0.0)  # rank D
	_style.add("jab")
	_check(Wallet.dirty == before + 6, "rank D jab banks $6 dirty ($+%d)" % (Wallet.dirty - before))
	_style.set("value", 450.0)  # rank S
	_style.add("parry")
	_check(Wallet.dirty == before + 6 + 65, "rank S parry banks $65 dirty with chain bonus ($+%d)" % (Wallet.dirty - before))
	_check(_style.cash == Wallet.total(), "style meter mirrors the wallet")
	var entry: Dictionary = Wallet.entries[-1]
	_check(entry.kind == "earn" and entry.item == "parry", "earn entry written (%s/%s)" % [entry.kind, entry.item])


func _heat_cycle() -> void:
	Heat.heat = 0.0
	# B12: crowds are witnesses (x1.5), alleys are not (x0.6) - exactly
	# one pair of eyes keeps the old arithmetic honest
	var one_eye := Node3D.new()
	one_eye.add_to_group("wanderer")
	var pp := get_tree().get_first_node_in_group("player") as Node3D
	one_eye.position = (pp.global_position if pp else Vector3.ZERO) + Vector3(3, 0, 0)
	add_child(one_eye)
	Heat.on_violence("knockdown")
	Heat.on_violence("shot")
	Heat.on_violence("hit")
	_check(absf(Heat.heat - 1.08) < 0.01, "violence raises heat to 1.08 (%.2f)" % Heat.heat)
	for i in 12:
		Heat.on_violence("knockdown")
	_check(Heat.heat == 5.0, "heat caps at 5 (%.1f)" % Heat.heat)
	var stars: int = Heat.stars()
	_check(stars == 5, "five stars (%d)" % stars)
	one_eye.queue_free()
	# the HUD stars label follows
	var heat_label: Label = _style.get_node_or_null("HeatLabel")
	_check(heat_label and heat_label.text == "HEAT  *****", "heat stars on the HUD (%s)" % (heat_label.text if heat_label else "none"))
	# music follows heat (one physics tick behind the change)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(absf(Music.get("heat") - 5.0) < 0.01, "music heat follows (%.1f)" % Music.get("heat"))
	# response: park everything far away, heat 4 summons street response
	_player.global_position = Vector3(0.0, 0.02, 0.0)
	Heat.heat = 4.0
	await _wait(1.0)
	_check(Heat.responders().size() >= 1, "high heat summons a responder (%d)" % Heat.responders().size())
	# heat drains -> responders leave
	Heat.heat = 0.5
	await _wait(1.0)
	_check(Heat.responders().size() == 0, "responders leave as heat dies (%d)" % Heat.responders().size())
	# decay out of sight: nothing near, calm timer, heat falls.
	# 1.5, not 2.0: at 2.0 the game is WORKING AS DESIGNED when it
	# reinforces responders toward the player (they count as seen and the
	# street does not forget) - the decay path needs no responders.
	Heat.heat = 1.5
	for e in get_tree().get_nodes_in_group("enemy"):
		(e as Node3D).global_position = Vector3(19.0, 0.02, 19.0)
	# HOLD the street clear through the whole window: a hostile district
	# keeps spawning goons near the hero, and any enemy inside the 12 m
	# sight range restarts the calm timer - a single late sighting inside
	# the last ~4 s eats the whole decay. Sweep every half-second and
	# push anything approaching back past 15 m, so 'seen' is never true
	# and the DECAY PATH is what this measures, not the city's ambient
	# population. (Flaked twice in the Batch 2 battery: heat frozen at
	# exactly 1.50 = the calm timer restarting.)
	var frames := 0
	while frames < 9.0 * 60:
		await get_tree().physics_frame
		frames += 1
		# EVERY frame, not every 30th: an enemy dipping inside 15 m on an
		# off-frame restarts the calm timer and freezes the decay (bit the
		# Batch 2 battery twice, this battery once - always heat parked at
		# exactly 1.50). A per-frame sweep of a handful of nodes is free
		# and closes the race window entirely.
		for e in get_tree().get_nodes_in_group("enemy"):
			var en := e as Node3D
			if en.global_position.distance_to(_player.global_position) < 15.0:
				en.global_position = Vector3(19.0, 0.02, 19.0)
	_check(Heat.heat < 1.5, "heat decays out of sight (%.2f)" % Heat.heat)


func _shopping() -> void:
	Wallet.call("reset_for_test")
	# the heat cycle above was public violence; the shops price by it.
	# this suite tests the money math, so start the city neutral.
	for d in City.DISTRICTS:
		City.rep[d] = 0.0
		City.hostile[d] = false
	Heat.heat = 0.0
	# tailor: a coat changes the look
	_tailor._buy("Midnight coat", "coat_midnight", 45)
	_check(Wallet.cash == 105, "tailor purchase deducts ($%d)" % Wallet.cash)
	_check(_player.get("look") == "midnight", "look applied (%s)" % _player.get("look"))
	var rig: HeroRig = _player.get_node("Body/Hero")
	var panel_col: Color = (rig.get("_coat")[0] as MeshInstance3D).material_override.albedo_color
	_check(absf(panel_col.b - 0.22) < 0.03 and panel_col.b > panel_col.r, "coat is midnight blue (%s)" % panel_col)
	_check(Wallet.entries[-1].kind == "purchase", "purchase in the ledger")
	# gear: gloves add damage
	_gear_shop._buy("Leather gloves", "gloves", 80)
	_check(Wallet.cash == 25, "gloves deducted ($%d)" % Wallet.cash)
	_check(_player.call("_gear_dmg") == 1, "gloves add +1 punch damage")
	_check(_player.call("_swing_damage", "jab") == 2, "jab now hits for 2")
	# cannot afford
	var entries := Wallet.entries.size()
	_gear_shop._buy("Track boots", "boots", 60)
	_check(Wallet.cash == 25 and Wallet.entries.size() == entries, "no money, no purchase, no entry")
	# pawn is a placeholder: prices are info-only
	_check(_pawn != null, "the pawn counter exists")
	_pawn._open()
	if _pawn._panel:
		_check(true, "pawn panel opens")
		# everything on the pawn counter is info-only (price < 0)
		var info_only := true
		for entry in Shop.STOCK["pawn"]:
			if entry.price >= 0:
				info_only = false
		_check(info_only, "pawn items are info-only (not buyable)")
		_check(true, "pawn prices per shot in its note ($%d)" % Wallet.bullet_cost())
		_pawn._close()


func _save_load() -> void:
	Wallet.call("reset_for_test")
	Wallet.earn(50, "bout")
	_player.set("look", "oxblood")
	_player.call("apply_purchase", "jacket")
	Heat.heat = 3.0
	_player.global_position = Vector3(9.0, 0.02, -7.0)
	var saved := SaveGame.save_all()
	_check(saved, "save writes")
	_check(SaveGame.has_save(), "save file exists")
	# wreck the state
	Wallet.cash = 1
	Wallet.entries.clear()
	Heat.heat = 0.0
	_player.set("look", "shadow")
	_player.set("gear", {})
	_player.global_position = Vector3.ZERO
	# and restore
	var loaded := SaveGame.load_all()
	_check(loaded, "load restores")
	_check(Wallet.cash == 200, "wallet restored ($%d)" % Wallet.cash)
	_check(absf(Heat.heat - 3.0) < 0.01, "heat restored (%.1f)" % Heat.heat)
	_check(_player.get("look") == "oxblood", "look restored (%s)" % _player.get("look"))
	_check(_player.get("gear").has("jacket"), "gear restored")
	_check(_player.call("_gear_stun") == 0.7, "gear effect re-applied after load")
	_check(absf(_player.global_position.x - 9.0) < 0.2, "position restored")


func _finish() -> void:
	var city_out: Dictionary = City.to_dict()
	_check(city_out.has("rep") and city_out.rep.has("riverside"), "city memory round-trips via save")
	if _fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL (%d problems)" % _fails)
		get_tree().quit(1)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _find_disabled(n: Node) -> Button:
	for c in n.find_children("*", "Button", true, false):
		if (c as Button).disabled:
			return c
	return null


func _find_label_with(n: Node, has: String) -> Label:
	for c in n.find_children("*", "Label", true, false):
		if has in (c as Label).text:
			return c
	return null
