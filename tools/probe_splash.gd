extends SceneTree

## One-off diagnostic: load the splash, tick, print phase + card count.
func _initialize() -> void:
	var root := get_root()
	var splash: Node = load("res://scenes/boot/splash.tscn").instantiate()
	root.add_child(splash)
	for i in 10:
		await create_timer(0.2).timeout
		print("t=%.1f phase=%d cards=%d running=%s" % [
			(i + 1) * 0.2, splash.get("phase"),
			(splash.get("_cards") as Array).size(),
			str(splash.get("_cards") as Array != null)])
	quit(0)
