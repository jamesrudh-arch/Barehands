extends Node
## Headless audio smoke test: buses, bank, impact layers, surface footsteps,
## sliders, ambience loops. Not part of the game.

var _fails := 0
var _checks := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("SMOKE FAIL: ", what)
	else:
		print("SMOKE ok: ", what)


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var opening := get_tree().get_first_node_in_group("opening") as OpeningShot
	if opening:
		opening.skip()
	await get_tree().physics_frame
	await get_tree().physics_frame

	# buses
	for bus in ["Master", "Music", "SFX", "Ambience", "Voice"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "bus %s exists" % bus)
	_check(AudioServer.get_bus_index("Master") == 0, "Master is bus 0")

	# bank
	var bank: Dictionary = Sound.get("_bank")
	_check(bank.size() >= 60, "bank loaded %d clips" % bank.size())
	for needed in ["punch_med_0", "punch_heavy_0", "step_asphalt_0", "step_wood_0",
			"splash_0", "cloth_0", "door_open_0", "coins_0", "hum", "rain_asphalt",
			"traffic", "siren", "ui_click_0", "music_bed"]:
		_check(bank.has(needed), "bank has %s" % needed)

	# impacts: every kind dispatches layered sound
	for kind in ["jab", "cross", "counter", "slam", "parry", "player_hit", "finisher"]:
		Fx.emit_hit(kind, Vector3.ZERO)
		var layers: Array = Sound.get("layers_played")
		_check(layers.size() >= 2, "%s layers %d sounds (%s)" % [kind, layers.size(),
				",".join(PackedStringArray(layers))])
	Fx.emit_hit("gun_test", Vector3.ZERO)
	_check(Sound.get("last_played").begins_with("gun_test"), "gun_test plays a shot")

	# footsteps by surface
	Sound.step("asphalt")
	_check(Sound.get("last_played").begins_with("step_asphalt"), "asphalt footstep")
	Sound.step("wood")
	_check(Sound.get("last_played").begins_with("step_wood"), "wood footstep")
	Sound.step("carpet")
	_check(Sound.get("last_played").begins_with("step_carpet"), "carpet footstep")
	Sound.step("puddle")
	_check(Sound.get("last_played").begins_with("splash"), "puddle splash footstep")
	Sound.step("metal")
	_check(Sound.get("last_played") == "metal_click_0", "metal = wood + metal click layer")

	# surface detection by position
	_check(Sound.surface_at(Vector3(7.0, 0.5, -6.0)) == "puddle", "puddle spot detected")
	_check(Sound.surface_at(Vector3(0.0, 0.5, 0.0)) == "asphalt", "road detected as asphalt")
	_check(Sound.surface_at(Vector3(7.0, 1.6, -8.3)) == "wood", "crate top detected as wood")

	# ambience loops + spatial hum
	var amb: Dictionary = Sound.get("_amb")
	_check(amb.size() >= 3, "%d ambience loops running" % amb.size())
	var neon := get_tree().get_first_node_in_group("neon") as Node
	var hums := neon.get_children().filter(func(c: Node) -> bool: return c is AudioStreamPlayer3D)
	_check(hums.size() == 3, "%d spatial neon hums" % hums.size())

	# sliders
	Sound.set_bus_vol("SFX", 0.5)
	_check(absf(Sound.get_bus_vol("SFX") - 0.5) < 0.02, "slider sets SFX to ~0.5")
	Sound.set_bus_vol("SFX", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "zero mutes the bus")
	Sound.set_bus_vol("SFX", 1.0)
	_check(!AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "restore unmutes")

	# volume settings persist
	Sound.set_bus_vol("Music", 0.7)
	Sound.call("_save_volumes")
	var ok := FileAccess.file_exists("user://settings.cfg")
	_check(ok, "settings.cfg written")
	if ok:
		var cfg := ConfigFile.new()
		cfg.load("user://settings.cfg")
		_check(absf(float(cfg.get_value("audio", "Music", 0.0)) - 0.7) < 0.02, "volume persisted")

	print("AUDIO memory static %.1f MB, bank %d clips" % [
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, bank.size()])
	if _fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL (%d problems)" % _fails)
		get_tree().quit(1)
