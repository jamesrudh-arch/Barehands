extends Node

## USER OVERRIDES R1/R2 + R3, street side. (1) ARRIVAL: when the hero
## walks out of the warehouse start scene, main.tscn boots with
## arrived_from=warehouse - this node lands them at the warehouse front
## on the foundry block (the docks), district set, camera snapped.
## (2) RETURN: the street's warehouse door (the shut roller front,
## group warehouse_door) becomes the way home - walk into it and you
## fade back to the warehouse scene. The door only exists once the
## foundry block builds (blocks are lazy), so the wire polls for it.
## (3) R3: the visible camera pad rides the UI layer here too.

const WAREHOUSE_SCENE := "res://scenes/warehouse.tscn"
const DOOR_WORLD := Vector3(482.0, 3.25, -6.85)   # the shut front's centre
const RETURN_SPAWN := Vector3(482.0, 0.02, -4.6)  # clear of the return zone

var _busy := false
var _fader: ColorRect = null


func _ready() -> void:
	_build_fade()
	_mount_cam_pad()
	_arrival()
	_wire_return_door()


## R3: the camera pad, mounted once, on the HUD layer.
func _mount_cam_pad() -> void:
	var ui := get_tree().get_first_node_in_group("hud") as CanvasLayer
	if ui and ui.get_node_or_null("CamPad") == null:
		var pad: Control = load("res://scripts/cam_stick.gd").new()
		pad.name = "CamPad"
		ui.add_child(pad)


## The hero arrives from the warehouse: the docks, at their own front
## door, facing it.
func _arrival() -> void:
	var arrived: Variant = Settings.value("arrived_from")
	if arrived == null or str(arrived) != "warehouse":
		return
	# Blocks resolves its main node by polling for the player; its
	# riverside default-district line runs in the same stretch, so
	# waiting for _main guarantees our foundry write lands after it
	for i in 240:
		if Blocks.get("_main") != null:
			break
		await get_tree().process_frame
	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero == null:
		return
	Blocks.call("_ensure", "foundry")
	hero.global_position = RETURN_SPAWN
	if "velocity" in hero:
		hero.velocity = Vector3.ZERO
	Blocks.set("_current", "foundry")
	City.set_current_district("foundry")
	Blocks.call("snap_camera_to", hero)
	Settings.set_value("arrived_from", "")
	Log.info("Arrival: from the warehouse, out onto the docks")


## The way home: walk into the shut front, fade back to the warehouse.
func _wire_return_door() -> void:
	for i in 1200:
		var door := get_tree().get_first_node_in_group("warehouse_door") as Node3D
		if door:
			Log.info("Arrival: wiring the return door (poll %d)" % i)
			_build_return_zone(door)
			return
		await get_tree().create_timer(0.3).timeout


func _build_return_zone(door: Node3D) -> void:
	var zone := Area3D.new()
	zone.name = "WarehouseReturn"
	zone.add_to_group("warehouse_return")
	zone.position = Vector3(DOOR_WORLD.x, 1.1, DOOR_WORLD.z + 0.5)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.6, 2.2, 1.2)
	col.shape = shape
	zone.add_child(col)
	zone.body_entered.connect(func(b):
		if b.is_in_group("player") and not _busy \
				and not bool(Blocks.get("_fading")):
			_goto_warehouse())
	door.get_parent().add_child(zone)
	var prompt := Label3D.new()
	prompt.text = "walk in - home"
	prompt.modulate = Color(0.5, 0.9, 0.7)
	prompt.font_size = 30
	prompt.position = Vector3(DOOR_WORLD.x, 1.9, DOOR_WORLD.z + 0.4)
	door.get_parent().add_child(prompt)
	zone.set_meta("target", WAREHOUSE_SCENE)


func _goto_warehouse() -> void:
	_busy = true
	var zone := get_tree().get_first_node_in_group("warehouse_return") as Node3D
	if zone:
		zone.set_meta("went_home", true)
	Log.info("Arrival: back through the front, home")
	await _fade_out()
	Settings.set_value("arrived_from", "street")
	get_tree().change_scene_to_file(WAREHOUSE_SCENE)


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArrivalFade"
	layer.layer = 90
	add_child(layer)
	_fader = ColorRect.new()
	_fader.color = Color(0, 0, 0, 0)
	_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fader)


func _fade_out() -> void:
	if _fader == null:
		return
	var dur := float(Settings.value("fade_s"))
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 1.0, dur)
	await tw.finished
