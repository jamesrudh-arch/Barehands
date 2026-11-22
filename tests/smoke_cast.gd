extends Node
const CLS_Cast := preload("res://scripts/cast.gd")
const CLS_NpcRig := preload("res://scripts/npc_rig.gd")
const CLS_OpeningShot := preload("res://scripts/opening_shot.gd")
## Headless smoke test for Series-2 Phase 7: the cast. Four distinct
## characters with rigs and colour identities, the noir dialogue system
## (typing, portraits, input lock, voice hooks), Velvet's counter hand-off,
## and rep-aware lines. Not part of the game.

var _main: Node3D
var _player: CharacterBody3D
var _cast: CLS_Cast
var _fails := 0
var _voice_hooked := {"speaker": "", "id": "", "index": -1}


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("SMOKE FAIL: ", what)
	else:
		print("SMOKE ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)  # the picker would lock input
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as CLS_OpeningShot
	if opening:
		opening.skip()
	_player = _main.get_node("Player") as CharacterBody3D
	_cast = _main.get_node("Cast") as CLS_Cast
	Wallet.call("reset_for_test")
	Dialogue.line_started.connect(func(speaker: String, id: String, index: int) -> void:
		_voice_hooked = {"speaker": speaker, "id": id, "index": index})
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _the_four()
	await _talking()
	await _velvet_handoff()
	await _voice_hooks()
	_finish()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _the_four() -> void:
	_check(_cast != null, "the cast node exists")
	_check(_cast.npcs.size() == 14, "fourteen street rigs (%d)" % _cast.npcs.size())
	var who := {}
	for n in _cast.npcs:
		who[n.name] = true
	for expected in ["Velvet", "Pilsner", "Marrow", "The Duchess", "Mama Sun",
			"Little Ash", "Tam", "Raz", "The Drunk", "Coach Okafor",
			"Officer Kessler", "The Mechanic", "The Club Owner", "Yuen"]:
		_check(who.get(expected, false), "named cast: %s present" % expected)
	# the bible's 16: the street fourteen + SAUL (phone-only, the kidnap
	# arc) + VULTURE (the wall-leaning watcher)
	_check(get_tree().get_first_node_in_group("watcher") != null,
			"Vulture (the watcher) is posted")
	_check(Trust.FRIENDS.has("brother"), "Saul (the brother) lives on the phone")
	var names := []
	for n in _cast.npcs:
		names.append(n.name)
	for want in ["Velvet", "Pilsner", "Marrow", "The Duchess"]:
		_check(names.has(want), "%s is in the cast" % want)
	# distinct colour identities (B22: fourteen, each unique - the
	# VLM inspection demands the cast read as individuals)
	var colors := []
	for n in _cast.npcs:
		colors.append(n.color.to_html())
	var uniq := {}
	for c in colors:
		uniq[c] = true
	_check(colors.size() == 14 and uniq.size() == 14,
			"fourteen distinct colour identities (%d rigs, %d unique)" % [
					colors.size(), uniq.size()])
	# each has a rigged body with the shared UAL rig playing an idle
	for n in _cast.npcs:
		var rig: CLS_NpcRig = (n.node as Node3D).get_node("Rig")
		var body := rig.find_children("Body", "Node", true, false)
		var rigged := false
		for b in body:
			var sc = (b as Node).get_script()
			if sc and str(sc.resource_path).contains("humanoid.gd"):
				rigged = true
		_check(rigged, "%s is rigged (the humanoid body)" % n.name)
		var anims := rig.find_children("Clips", "AnimationPlayer", true, false)
		var playing := anims.size() > 0
		for a in anims:
			if not (a as AnimationPlayer).is_playing():
				playing = false
		_check(playing, "%s is animated (%d players)" % [n.name, anims.size()])
	# silhouettes: Marrow is the biggest, Pilsner wears glasses, the Duchess a circlet
	var marrow := _cast.npcs[2].node as Node3D
	_check(marrow.scale.x > 1.1, "Marrow stands biggest (%.2f)" % marrow.scale.x)
	var pilsner := _cast.npcs[1].node as Node3D
	var glasses := 0
	for mi in pilsner.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh is TorusMesh:
			glasses += 1
	_check(glasses >= 2, "Pilsner wears glasses (%d lenses)" % glasses)
	var duchess := _cast.npcs[3].node as Node3D
	var spikes := 0
	for mi in duchess.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh is CylinderMesh:
			spikes += 1
	_check(spikes >= 1, "The Duchess wears a circlet")
	_check(duchess.global_position.y > 3.0, "The Duchess watches from the roof (%.1f m)" % duchess.global_position.y)


func _talking() -> void:
	# walk to Velvet and GRAB
	var velvet: Node3D = _cast.npcs[0].node
	_player.global_position = velvet.global_position + Vector3(0.0, 0.02, 1.2)
	_player.velocity = Vector3.ZERO
	await _wait(0.2)
	InputBus.queue_grab()
	await _wait(0.2)
	_check(Dialogue.is_active(), "GRAB near Velvet starts dialogue")
	_check(InputBus.locked, "dialogue locks gameplay input")
	# typing: text fills gradually, then a tap finishes the line
	await _wait(0.25)
	var partial: String = Dialogue.get("_text").text
	_check(partial.length() > 0 and partial.length() < 90, "text types out (%d chars so far)" % partial.length())
	var name_l: Label = Dialogue.get("_name")
	_check(name_l.text == "Velvet", "portrait name shows Velvet (%s)" % name_l.text)
	Dialogue._advance()  # finish typing
	Dialogue._advance()  # next line
	await _wait(0.1)
	var text2: String = Dialogue.get("_full_text")
	_check("ledger" in text2.to_lower() or "bullet" in text2.to_lower(),
			"second line is Velvet's (%s)" % text2.substr(0, 40))
	Dialogue._advance()  # finish line 2 typing
	Dialogue._advance()  # close (2 base lines)
	await _wait(0.1)
	_check(not Dialogue.is_active(), "dialogue closes after the lines")
	# her talk hands off to the pawn counter, which locks input while
	# browsing - close it, then input must be free again
	_close_pawn_if_open()
	await _wait(0.1)
	_check(not InputBus.locked, "input unlocks after dialogue (counter closed)")


func _close_pawn_if_open() -> void:
	for s in get_tree().get_nodes_in_group("pawn_counter"):
		if s._panel != null:
			s._close()


func _velvet_handoff() -> void:
	# high rep in her district adds a third, warmer line
	City.rep["foundry"] = 45.0
	_close_pawn_if_open()
	InputBus.queue_grab()
	await _wait(0.2)
	_check(Dialogue.is_active(), "Velvet talks again")
	for i in 4:
		Dialogue._advance()
		await _wait(0.05)
	Dialogue._advance()
	await _wait(0.2)
	# talking to Velvet ends by opening her gun counter (any earlier panel
	# from the first talk is already closed, so this one is the handoff)
	_close_pawn_if_open()
	await _wait(0.05)
	InputBus.queue_grab()
	await _wait(0.2)
	for i in 5:
		Dialogue._advance()
		await _wait(0.03)
	await _wait(0.2)
	var pawn := get_tree().get_nodes_in_group("pawn_counter")
	_check(pawn.size() == 1, "Velvet's counter is found")
	if pawn.size() == 1:
		var open: bool = pawn[0]._panel != null
		_check(open, "Velvet's talk hands off to her counter")
		if open:
			pawn[0]._close()
	City.rep["foundry"] = 0.0


func _voice_hooks() -> void:
	# the hook fires per line with the right voice id; no recording -> silent
	City.hostile["foundry"] = false
	InputBus.queue_grab()
	await _wait(0.2)
	Dialogue._advance()
	await _wait(0.1)
	_check(_voice_hooked.speaker == "Velvet" and _voice_hooked.id == "velvet"
			and _voice_hooked.index >= 0, "voice hook fires (speaker %s, id %s, line %d)" % [
			_voice_hooked.speaker, _voice_hooked.id, _voice_hooked.index])
	var vp: AudioStreamPlayer = Dialogue.get("_voice")
	_check(vp.bus == "Voice" and vp.stream == null, "voice hook is clean (Voice bus, no recording yet)")
	Dialogue._advance()
	Dialogue._advance()
	await _wait(0.1)


func _finish() -> void:
	if _fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL (%d problems)" % _fails)
		get_tree().quit(1)
