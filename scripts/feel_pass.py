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
# 1) THE CAMERA LANGUAGE (camera_rig.gd): trauma-decay shake,
#    sprint FOV kick, handheld drift. The rig was silent - no
#    impulse API, no kick, no idle life.
# ============================================================
patch("scripts/player/camera_rig.gd", [
("""const ARM_LEN := 3.4
const PITCH_MIN := -0.55
const PITCH_MAX := 0.95
const SENS := 0.0026""",
"""const ARM_LEN := 3.4
const PITCH_MIN := -0.55
const PITCH_MAX := 0.95
const SENS := 0.0026

# S5.17 THE FEEL PASS: the camera SPEAKS. Trauma-shake (impulse
# in, quadratic falloff out - the Squirrel Eiserloh model), a
# sprint FOV kick, and a handheld drift when the hero stands.
# A silent camera reads as a dev viewport; a talking one reads
# as a game.
const FOV_BASE := 68.0
const FOV_SPRINT := 74.0
const SHAKE_DECAY := 3.4   # trauma units per second
const DRIFT_FREQ := 0.55   # the handheld sway (rad/s, slow)"""),
("""var _arm: SpringArm3D
var _cam: Camera3D
var _light: OmniLight3D  # the face light (the architecture's rule)""",
"""var _arm: SpringArm3D
var _cam: Camera3D
var _light: OmniLight3D  # the face light (the architecture's rule)
var _trauma := 0.0       # 0..1, squared for the shake amount
var _t_sway := 0.0

## Impulse-based shake: 0.3 = a jab landed, 1.0 = a super. Sums
## while hot (two hits in a row stack), decays in ~0.3 s.
func add_impulse(strength: float) -> void:
	_trauma = minf(_trauma + clampf(strength, 0.0, 1.0), 1.0)"""),
("""	var hero := get_tree().get_first_node_in_group("player") as Node3D
	if hero:
		global_position = global_position.lerp(
				hero.global_position + Vector3(0, 1.45, 0),
				clampf(delta * 18.0, 0.0, 1.0))
	_apply()""",
"""	var hero := get_tree().get_first_node_in_group("player") as Node3D
	var hero_speed := 0.0
	if hero:
		global_position = global_position.lerp(
				hero.global_position + Vector3(0, 1.45, 0),
				clampf(delta * 18.0, 0.0, 1.0))
		var body := hero as CharacterBody3D
		if body:
			hero_speed = Vector2(body.velocity.x,
					body.velocity.z).length()
	# THE KICK: near run speed widens the lens (68 -> 74) and eases
	# back at walk - speed gets a FOCAL weight, not just a volume
	var kick_t: float = clampf((hero_speed - 3.2) / 2.4, 0.0, 1.0)
	_cam.fov = lerpf(_cam.fov, FOV_BASE + (FOV_SPRINT - FOV_BASE)
			* kick_t, clampf(delta * 6.0, 0.0, 1.0))
	# THE SHAKE: trauma^2 so small hits whisper and big ones slam;
	# three detuned trig channels (x/y pos + roll), never pitch -
	# pitch shake fights the player's look stick
	_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
	var shake := _trauma * _trauma
	_t_sway += delta
	var sx := sin(_t_sway * 37.0) * 0.5 + sin(_t_sway * 61.0) * 0.5
	var sy := sin(_t_sway * 43.0) * 0.5 + sin(_t_sway * 71.0) * 0.5
	_cam.position = Vector3(
			sx * shake * 0.14,
			sy * shake * 0.11,
			-shake * 0.06)
	_cam.rotation.z = sx * shake * 0.035
	# THE DRIFT: a handheld camera breathes when the hero stands -
	# a locked frame reads as a surveillance feed
	var calm := 1.0 - clampf(hero_speed / 1.0, 0.0, 1.0)
	if calm > 0.0:
		_cam.position += Vector3(
				sin(_t_sway * DRIFT_FREQ) * 0.012,
				sin(_t_sway * DRIFT_FREQ * 1.37) * 0.018, 0.0) * calm
	_apply()"""),
])

# ============================================================
# 2) THE IMPACT SITE (combat.gd): weight-scaled hitstop (flat
#    0.05 served jabs and heavies identically) + the camera
#    speaks on every landed blow + landing dust.
# ============================================================
patch("scripts/player/combat.gd", [
("""		Fx.emit_hit("kick", from + fwd * 1.2)
		_hitstop_s = 0.05  # the selective freeze, attacker only""",
"""		Fx.emit_hit("kick", from + fwd * 1.2)
		# S5.17: hitstop carries the move's WEIGHT - a jab nips
		# (0.04 s), a heavy or a super SLAMS (0.10 s). Flat 0.05
		# made every hit read the same.
		var weight: float = clampf(
				float(_attack.damage) / 26.0, 0.0, 1.0)
		_hitstop_s = lerpf(0.04, 0.10, weight)
		# the camera answers every landed blow (0.25 jab whisper
		# -> 0.6 heavy slam; stacks through the trauma model)
		var rig := get_tree().get_first_node_in_group(
				"camera_rig") as Node3D
		if rig and rig.has_method("add_impulse"):
			rig.add_impulse(lerpf(0.25, 0.6, weight))"""),
])
print("FEEL PASS PATCHES APPLIED")
