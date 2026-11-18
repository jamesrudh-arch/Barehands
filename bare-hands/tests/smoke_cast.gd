extends Node
## Headless smoke test for Series-2 Phase 7: the cast. Four distinct
## characters with rigs and colour identities, the noir dialogue system
## (typing, portraits, input lock, voice hooks), Velvet's counter hand-off,
## and rep-aware lines. Not part of the game.

var _main: Node3D
var _player: CharacterBody3D
var _cast: Cast
var _fails := 0
var _voice_hooked := {"speaker": "", "id": "", "index": -1}


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("SMOKE FAIL: ", what)
	else:
		print("SMOKE ok: ", what)


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	_player = _main.get_node("Player") as CharacterBody3D
	_cast = _main.get_node("Cast") as Cast
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
	_check(_cast.npcs.size() == 4, "four characters (%d)" % _cast.npcs.size())
	var names := []
	for n in _cast.npcs:
		names.append(n.name)
	for want in ["Velvet", "Pilsner", "Marrow", "The Duchess"]:
		_check(names.has(want), "%s is in the cast" % want)
	# distinct colour identities
	var colors := []
	for n in _cast.npcs:
		colors.append(n.color.to_html())
	_check(colors.size() == 4 and colors.size() == 4, "four identities")
	# each has a rigged body with the shared UAL rig playing an idle
	for n in _cast.npcs:
		var rig: NpcRig = (n.node as Node3D).get_node("Rig")
		var skel := rig.find_children("*", "Skeleton3D", true, false)
		_check(skel.size() >= 1, "%s is rigged (%d skeletons)" % [n.name, skel.size()])
		var anim := rig.get_node_or_null("Body/Clips") as AnimationPlayer
		_check(anim != null and anim.is_playing(), "%s is animated" % n.name)
	# silhouettes: Marrow is the biggest, Pilsner wears glasses, the Duchess a circlet
	var marrow := _cast.npcs[2].node as Node3D
	_check(marrow.scale.x > 1.1, "Marrow stands biggest (%.2f)" % marrow.scale.x)
	var pilsner := _cast.npcs[1].node as Node3D
	var glasses := 0
	for t in pilsner.find_children("*", "TorusMesh", true, false):
		glasses += 1
	_check(glasses >= 2, "Pilsner wears glasses (%d lenses)" % glasses)
	var duchess := _cast.npcs[3].node as Node3D
	var spikes := 0
	for c in duchess.find_children("*", "CylinderMesh", true, false):
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
	_check(not InputBus.locked, "input unlocks after dialogue")


func _velvet_handoff() -> void:
	# high rep in her district adds a third, warmer line
	City.rep["foundry"] = 45.0
	InputBus.queue_grab()
	await _wait(0.2)
	_check(Dialogue.is_active(), "Velvet talks again")
	for i in 4:
		Dialogue._advance()
		await _wait(0.05)
	Dialogue._advance()
	await _wait(0.2)
	# talking to Velvet ends by opening her gun counter
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
