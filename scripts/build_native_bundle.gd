extends SceneTree

## THE NATIVE BUNDLE BUILDER (overhaul S5.1): packs a cast GLB into
## a self-contained .tscn (FLAG_BUNDLE_RESOURCES - meshes, materials
## AND textures embedded, no import-cache dependency on the device;
## the D3 law + the S5.0 lesson). Run headless:
##   godot --headless --path . -s res://scripts/build_native_bundle.gd \
##       -- res/assets/... out_name

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -s build_native_bundle.gd -- <glb> <name>")
		quit(1)
		return
	var glb_path := args[0]
	var name := args[1]
	var packed_src: PackedScene = load(glb_path)
	if packed_src == null:
		push_error("bundle: cannot load %s" % glb_path)
		quit(1)
		return
	var rig: Node3D = packed_src.instantiate()
	root.add_child(rig)
	# force one frame so skins/meshes settle before the pack
	await process_frame
	var packed := PackedScene.new()
	var err := packed.pack(rig)
	if err != OK:
		push_error("bundle: pack failed (%d)" % err)
		quit(1)
		return
	var out := "res://assets/native/%s.tscn" % name
	var err2 := ResourceSaver.save(packed, out,
			ResourceSaver.FLAG_BUNDLE_RESOURCES)
	if err2 != OK:
		push_error("bundle: save failed (%d)" % err2)
		quit(1)
		return
	var f := FileAccess.open(out, FileAccess.READ)
	var ext := 0
	if f:
		ext = f.get_as_text().count("res://assets")
		f.close()
	print("BUNDLE %s -> %s (external asset refs: %d)" % [
			glb_path, out, ext])
	quit(0)
