extends Node
## Headless wrapper for the in-game TestRunner: boots the autoloads, runs
## every logic test, prints the report, exits 0/1 by pass count. Same code
## path the phone's debug menu runs.

func _ready() -> void:
	Settings.set_value("first_run_done", true)
	var runner := TestRunner.new()
	add_child(runner)
	await get_tree().process_frame
	runner._run_all()
	await get_tree().process_frame
	var passed := 0
	for r in runner._results:
		if r[1]:
			passed += 1
	print("TESTRUNNER %d/%d" % [passed, runner._results.size()])
	get_tree().quit(0 if passed == runner._results.size() else 1)
