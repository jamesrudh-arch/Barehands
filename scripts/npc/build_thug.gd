extends SceneTree

## THE THUG CONVERSION (rebuild step 11): packs the KayKit Barbarian
## into a native bundled .tscn with the shared animation library
## pre-installed - the same D3 pattern as the hero. Run once:
##   godot --headless --path . -s res://scripts/npc/build_thug.gd

const SRC := "res://assets/v2/kaykit_adventurers/Barbarian.glb"
const OUT := "res://assets/native/thug_kaykit_barbarian.tscn"
const CLS_KayKitLib := preload("res://scripts/player/kaykit_lib.gd")


func _init() -> void:
	var packed_src: PackedScene = load(SRC)
	if packed_src == null:
		printerr("THUG: source missing (%s)" % SRC)
		quit(1)
		return
	var rig: Node3D = packed_src.instantiate()
	root.add_child(rig)
	var skel := _find(rig, Skeleton3D) as Skeleton3D
	var player := _find(rig, AnimationPlayer) as AnimationPlayer
	if player == null:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		rig.add_child(player)
	player.root_node = player.get_path_to(rig)
	var shared: int = CLS_KayKitLib.install(player, skel)
	if shared < 4:
		printerr("THUG: library share failed (%d)" % shared)
		quit(1)
		return
	var packed := PackedScene.new()
	packed.pack(rig)
	var err := ResourceSaver.save(packed, OUT,
			ResourceSaver.FLAG_BUNDLE_RESOURCES)
	var f := FileAccess.open(OUT, FileAccess.READ)
	var refs := f.get_as_text().count("res://assets") if f else -1
	if f:
		f.close()
	print("THUG: %s saved (err %d, %d clips, %d external refs)" % [
			OUT, err, shared, refs])
	quit(0 if err == OK and refs == 0 else 1)


func _find(root_n: Node, what) -> Node:
	if root_n == null:
		return null
	if is_instance_of(root_n, what):
		return root_n
	for c in root_n.get_children():
		var f := _find(c, what)
		if f:
			return f
	return null
