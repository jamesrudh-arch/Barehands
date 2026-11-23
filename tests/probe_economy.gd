extends Node
## S5.5 ECONOMY GATE: the phone LEDGER reads the split (DIRTY /
## CLEAN / THE DEBT) and wears the quick-pay chip.
func _wait_s(s: float) -> void:
	var left := s
	while left > 0.0:
		var step := minf(0.1, left)
		await get_tree().create_timer(step).timeout
		left -= step

func _ready() -> void:
	var dog := get_tree().create_timer(70.0)
	dog.timeout.connect(func(): get_tree().quit(0))
	Settings.set_value("first_run_done", true)
	WorldState.reset()
	for i in 4:
		await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	await Game.start_new_game()
	await _wait_s(1.5)
	# a launderer's evening: dirty moved, clean banked, debt standing
	WorldState.set_value("stash_cash", 850.0)
	WorldState.set_value("clean_cash", 480.0)
	WorldState.set_value("debt", 4900.0)
	var phone: Array = Game.find_children("Phone", "CanvasLayer",
			false, false)
	if phone.size() == 0:
		print("ECON GATE FAIL: no phone")
		get_tree().quit(1)
		return
	phone[0].open(false)
	await _wait_s(0.6)
	get_viewport().get_texture().get_image().save_png(
			"/tmp/shots/econ_ledger.png")
	print("ECON GATE captured")
	get_tree().quit(0)
