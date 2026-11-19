extends Node
## Headless adaptive-music smoke test. Not part of the game.

const BAR := 60.0 / 88.0 * 4.0

var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("SMOKE FAIL: ", what)
	else:
		print("SMOKE ok: ", what)


func _wait_bars(n: float) -> void:
	await get_tree().create_timer(BAR * n + 0.2, true, false, true).timeout


func _ready() -> void:
	Settings.set_value("first_run_done", true)  # isolated user dir: no first-run picker
	# layers exist and are playing on the Music bus
	for stem in ["music_bed", "music_tension", "music_combat", "music_heartbeat"]:
		var vol := Music.layer_vol(stem)
		_check(vol > -80.0, "layer %s exists" % stem)
	_check(beat_phase_ok(), "beat phase in 0..1 (got %.2f)" % Music.beat_phase)

	# bed rises in explore
	await _wait_bars(1.5)
	_check(Music.layer_vol("music_bed") > -20.0, "bed rises in explore (%.1f dB)" % Music.layer_vol("music_bed"))
	_check(Music.layer_vol("music_combat") < -30.0, "combat silent in explore")

	# tension fades in on bar boundaries
	Music.force_state("tension")
	await _wait_bars(2.0)
	_check(Music.layer_vol("music_tension") > -25.0, "tension fades in (%.1f dB)" % Music.layer_vol("music_tension"))
	_check(Music.layer_vol("music_combat") < -30.0, "combat still silent in tension")

	# combat rises with style rank
	Music.set_style_rank(4)
	Music.force_state("combat")
	await _wait_bars(2.0)
	_check(Music.layer_vol("music_combat") > -8.0, "combat layer up at rank S (%.1f dB)" % Music.layer_vol("music_combat"))
	_check(Music.layer_vol("music_bed") < Music.layer_vol("music_combat"), "bed ducks under combat")

	# rank drops -> combat layer settles lower
	Music.set_style_rank(0)
	Music.force_state("combat")
	await _wait_bars(2.0)
	_check(Music.layer_vol("music_combat") < -6.0, "combat calmer at rank D (%.1f dB)" % Music.layer_vol("music_combat"))

	# heartbeat speeds with heat
	Music.set_heat(0.0)
	await get_tree().create_timer(0.3).timeout
	Music.set_heat(5.0)
	await get_tree().create_timer(0.3).timeout
	var hb_speed: float = Music.get("_layers")["music_heartbeat"].pitch_scale
	_check(hb_speed > 1.4, "heartbeat speeds up with heat (%.2fx)" % hb_speed)
	Music.set_heat(0.0)

	# resolve: everything ducks, resolve phrase plays, then bed returns
	var resolves_before: int = Music.get("_resolve_count")
	Music.force_state("resolve")
	_check(Music.get("_resolve_count") == resolves_before + 1, "resolve phrase triggered")
	var one: AudioStreamPlayer = Music.get("_resolve_one")
	_check(one.playing, "resolve one-shot is playing")
	await _wait_bars(4.0)
	_check(Music.layer_vol("music_bed") > -30.0, "bed returns after resolve (%.1f dB)" % Music.layer_vol("music_bed"))

	# dialogue duck dips and restores the Music bus
	var idx := AudioServer.get_bus_index("Music")
	var before := AudioServer.get_bus_volume_db(idx)
	Music.duck(-8.0, 0.3)
	await get_tree().create_timer(0.12).timeout
	_check(AudioServer.get_bus_volume_db(idx) < before - 4.0, "duck dips the Music bus")
	await get_tree().create_timer(0.6).timeout
	_check(absf(AudioServer.get_bus_volume_db(idx) - before) < 1.0, "duck restores the Music bus")

	if _fails == 0:
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL (%d problems)" % _fails)
		get_tree().quit(1)


func beat_phase_ok() -> bool:
	return Music.beat_phase >= 0.0 and Music.beat_phase < 1.0
