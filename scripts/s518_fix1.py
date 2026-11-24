import os
def patch(rel, pairs):
    s = open(rel).read()
    for old, new in pairs:
        if old not in s:
            print("MISS %s:\n%s" % (rel, old[:80])); raise SystemExit(1)
        s = s.replace(old, new, 1)
    open(rel, "w").write(s)
    print("patched", rel)

# 1) COLD OPEN: the frame must SHOW the loft (the dim stacked on
#    the noir lens crushed it to black); the text gets an outline
#    so it reads on any backdrop; the label anchors span the frame
patch("scripts/boot/cold_open.gd", [
("""	_dim.color = Color(0, 0, 0, 0.35)""",
"""	_dim.color = Color(0, 0, 0, 0.12)  # the lens already grades"""),
("""	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color",
			Color(0.95, 0.96, 0.99))""",
"""	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color",
			Color(0.97, 0.97, 1.0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color",
			Color(0, 0, 0, 0.9))"""),
("""	_label.position = Vector2(40, -108)""",
"""	_label.anchor_left = 0.07
	_label.anchor_right = 0.93
	_label.position = Vector2(0, -116)"""),
("""	_speaker.add_theme_color_override("font_color",
			Color(0.78, 0.82, 0.9))""",
"""	_speaker.add_theme_color_override("font_color",
			Color(1.0, 0.86, 0.5))
	_speaker.add_theme_constant_override("outline_size", 4)
	_speaker.add_theme_color_override("font_outline_color",
			Color(0, 0, 0, 0.85))"""),
])

# 2) THE TRAIN: each car reads as a LIT BAR - the side strip +
#    bigger windows at full emission. Small emissive windows
#    against the navy sky did zero work under the ACES grade.
patch("scripts/world/el_train.gd", [
("""	glow_mat.emission_energy_multiplier = 2.2""",
"""	glow_mat.emission_energy_multiplier = 4.5"""),
("""		# THE WINDOWS: emissive quads along both flanks - the lit
		# cars are the whole image at night
		for side in [-1.02, 1.02]:
			for w in 4:
				var win := MeshInstance3D.new()
				var wm := QuadMesh.new()
				wm.size = Vector2(0.9, 0.7)""",
"""		# THE WINDOWS: emissive quads along both flanks - the lit
		# cars are the whole image at night
		for side in [-1.03, 1.03]:
			for w in 5:
				var win := MeshInstance3D.new()
				var wm := QuadMesh.new()
				wm.size = Vector2(1.0, 0.8)"""),
("""				win.position = Vector3(
						body.position.x - 1.8 + w * 1.2,
						0.15, side)
				win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				car.add_child(win)""",
"""				win.position = Vector3(
						body.position.x - 2.1 + w * 1.05,
						0.18, side)
				win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				car.add_child(win)
		# THE STRIP: a full-length warm bar under each car's window
		# line - the car reads as ONE lit shape, not five dots
		for side in [-1.05, 1.05]:
			var strip := MeshInstance3D.new()
			var sm := QuadMesh.new()
			sm.size = Vector2(CAR_LEN - 0.6, 0.16)
			var stmat: StandardMaterial3D = \\
					glow_mat.duplicate() as StandardMaterial3D
			stmat.emission_energy_multiplier = 3.0
			sm.material = stmat
			strip.mesh = sm
			strip.rotation.y = PI / 2.0 if side < 0 else -PI / 2.0
			strip.position = Vector3(0, -0.28, side)
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			car.add_child(strip)"""),
])

# 3) THE GATE CAMERA: frame the train mid-crossing from the
#    street looking up, and the call shot waits for a full line
patch("tests/gate_intro.gd", [
("""	var t := get_tree().current_scene.find_child("ElTrain", true,
			false) as Node
	if t:
		t.set("_t_until", 0.05)
		await _wait_s(5.0)
		await _snap("el_train")""",
"""	var t := get_tree().current_scene.find_child("ElTrain", true,
			false) as Node
	if t:
		t.set("_t_until", 0.05)
		await _wait_s(3.6)
		var hero := get_tree().get_first_node_in_group(
				"player") as Node3D
		hero.global_position = Vector3(-14.0, 0.05, 3.0)
		hero.rotation.y = 0.0
		var tcam := Camera3D.new()
		tcam.name = "TrainCam"
		get_tree().current_scene.add_child.call_deferred(tcam)
		await get_tree().process_frame
		var oldc := get_viewport().get_camera_3d()
		if oldc:
			oldc.current = false
		tcam.current = true
		tcam.global_position = Vector3(-14.0, 2.1, 4.2)
		tcam.look_at(Vector3(-22.0, 9.4, -6.0))
		tcam.fov = 62.0
		await _wait_s(1.4)
		await _snap("el_train")"""),
])
