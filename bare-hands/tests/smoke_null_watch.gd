extends Node
## smoke_null_watch (B16): boots the REAL main scene and runs the
## first 600 frames without skipping anything - the opening flies,
## systems come up - and fails if ANY script error appears in that
## window. The Xogot lesson: the device spammed
##   fight_score.gd:38 'state' on Nil
## every frame while every sandbox suite was green, because a null
## autoload reference only shows up when it actually breaks. In-game
## GDScript cannot capture native error output, so the FRAME-RUNNER
## here counts frames and asserts the tree state; the battery wrapper
## greps this run's log for SCRIPT ERROR / Nil / null and fails the
## suite if any appear in the first 600 frames.
##
## Also asserts the end state: hero alive, touch controls visible,
## the cinematic finished (or the watchdog due), input unlocked.

var _frames := 0
var _born_ms := 0
var _waited := false


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_born_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 600:
		return  # the first 600 frames run untouched (the error window)
	if not _waited:
		# headless frames tick faster than wall clock: the 7 s opening
		# needs real time, so wait for it (or the 12 s watchdog)
		_waited = true
	if not OpeningShot.ever_finished \
			and Time.get_ticks_msec() - _born_ms < 25000:
		return
	_judge()
	print("NULLWATCH info: judged at frame %d (%.1f s wall)" % [
			_frames, (Time.get_ticks_msec() - _born_ms) / 1000.0])
	get_tree().quit(0 if _fails == 0 else 1)


var _fails := 0


func _check(ok: bool, what: String) -> void:
	print("NULLWATCH %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _judge() -> void:
	var hero := get_tree().get_first_node_in_group("player")
	_check(hero != null and is_instance_valid(hero),
			"the hero survived 600 frames")
	var hud := get_tree().get_first_node_in_group("hud")
	var buttons := 0
	if hud:
		for c in hud.get_children():
			if c is ActionButton and (c as ActionButton).visible:
				buttons += 1
	_check(buttons >= 3, "touch controls visible after 600 frames (%d)" % buttons)
	_check(OpeningShot.ever_finished or false,
			"the cinematic finished inside 600 frames (or the watchdog will)")
	_check(not InputBus.locked or not OpeningShot.ever_finished,
			"input unlocked once the cinematic landed")
	_check(Music != null, "the Music singleton is alive (the :38 root cause)")
	print("NULLWATCH %s (%d frames, %d fails)" % [
			"PASS" if _fails == 0 else "FAIL", _frames, _fails])
