extends SceneTree

## Rebuild step 1: register the ONE input map (06_CONTROL_MAP.md) via
## InputMap and save, so the engine itself serialises the event
## objects. Desktop keyboard + gamepad fallbacks; the touch UI feeds
## the same actions (InputEventAction with strength), so every input
## path speaks one table.
##
## Run: godot --headless --path . --script tools/rebuild_set_inputs.gd

const ACTIONS := {
	# on foot
	"move_left": ["K:A", "JX:-1"],
	"move_right": ["K:D", "JX:1"],
	"move_up": ["K:W", "JY:-1"],
	"move_down": ["K:S", "JY:1"],
	"look_left": ["K:LEFT", "JX2:-1"],
	"look_right": ["K:RIGHT", "JX2:1"],
	"look_up": ["K:UP", "JY2:-1"],
	"look_down": ["K:DOWN", "JY2:1"],
	"punch": ["K:X", "JB:2"],
	"heavy": ["K:C", "JB:3"],
	"kick": ["K:V", "JB:0"],
	"dodge": ["K:B", "JB:1"],
	"guard": ["K:G", "JB:5"],
	"grab": ["K:F", "JB:4"],
	"sprint": ["K:SHIFT", "JB:10"],
	"jump": ["K:SPACE", "JB:7"],
	"lock": ["K:Q", "JB:8"],
	"style": ["K:TAB", "JB:9"],
	"super": ["K:R", "JB:12"],
	"phone": ["K:P", "JB:11"],
	"pause": ["K:ESCAPE", "JB:6"],
	# vehicle
	"accelerate": ["K:W", "JB:7"],
	"brake": ["K:S", "JB:6"],
	"handbrake": ["K:H", "JB:0"],
	"horn": ["K:N", "JB:2"],
	# weapons
	"aim": ["K:Z", "JB:9"],
	"shoot": ["K:ENTER", "JB:7"],
	"reload": ["K:T", "JB:3"],
	"swap_weapon": ["K:E", "JB:4"],
}


func _initialize() -> void:
	var count := 0
	for action in ACTIONS:
		# runtime InputMap (this session) ...
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var events: Array[InputEvent] = []
		for spec in ACTIONS[action]:
			var ev := _event(spec)
			if ev:
				InputMap.action_add_event(action, ev)
				events.append(ev)
				count += 1
		# ... and the persisted setting (the editor's own route:
		# input/<action> is a {deadzone, events} dictionary setting)
		ProjectSettings.set_setting("input/%s" % action,
				{"deadzone": 0.2, "events": events})
	ProjectSettings.save()
	print("input map: %d actions, %d events saved" % [ACTIONS.size(), count])
	quit(0)


func _event(spec: String) -> InputEvent:
	var parts := spec.split(":")
	match parts[0]:
		"K":
			var ev := InputEventKey.new()
			ev.physical_keycode = OS.find_keycode_from_string(parts[1])
			return ev
		"JB":
			var ev := InputEventJoypadButton.new()
			ev.button_index = int(parts[1]) as JoyButton
			return ev
		"JX", "JY":
			var ev := InputEventJoypadMotion.new()
			ev.axis = 0 if parts[0] == "JX" else 1
			ev.axis_value = float(parts[1])
			return ev
		"JX2", "JY2":
			var ev := InputEventJoypadMotion.new()
			ev.axis = 2 if parts[0] == "JX2" else 3
			ev.axis_value = float(parts[1])
			return ev
	return null
