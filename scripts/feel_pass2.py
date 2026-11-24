import os
ROOT = "/home/z/my-project"

def patch(rel, pairs):
    path = os.path.join(ROOT, rel)
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (rel, old[:90]))
            raise SystemExit(1)
        s = s.replace(old, new, 1)
    open(path, "w").write(s)
    print("patched %s" % rel)

# ============================================================
# 3) THE HIT FLASH (enemy.gd): the classic fighter read - a
#    white additive silhouette pop on every landed blow. The
#    hitstun state existed with NO visual signature; damage
#    read as nothing without watching the HP bar.
# ============================================================
patch("scripts/npc/enemy.gd", [
("""	hp -= damage
	posture -= posture_damage
	state = State.HITSTUN
	_t = 0.0
	velocity = from_dir.normalized() * knockback
	move_and_slide()""",
"""	hp -= damage
	posture -= posture_damage
	state = State.HITSTUN
	_t = 0.0
	velocity = from_dir.normalized() * knockback
	move_and_slide()
	_flash_hit()"""),
("""func take_hit(damage: float, knockback: float, from_dir: Vector3,
		posture_damage: float) -> void:""",
"""## THE HIT FLASH (S5.17): a white additive billboard pops on the
## chest for 90 ms - the 2D-fighter law that reads at any camera
## distance. Per-instance quad, no shared-material surgery (the
## Kenney mats are one resource across every enemy on the street).
func _flash_hit() -> void:
	if _flash and is_instance_valid(_flash):
		_flash.queue_free()
	var m := MeshInstance3D.new()
	m.name = "HitFlash"
	var qm := QuadMesh.new()
	qm.size = Vector2(1.15, 1.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	qm.material = mat
	m.mesh = qm
	m.position = Vector3(0, 1.05, 0)
	add_child(m)
	_flash = m
	# pop on, fade out, gone in 90 ms (a scene-tree timer, not a
	# tween - the enemy may free itself mid-hit)
	get_tree().create_timer(0.09).timeout.connect(func():
		if _flash and is_instance_valid(_flash):
			_flash.queue_free())


var _flash: MeshInstance3D = null


func take_hit(damage: float, knockback: float, from_dir: Vector3,
		posture_damage: float) -> void:"""),
])
