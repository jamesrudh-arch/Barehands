extends Node3D

## A TRAINING TARGET (rebuild step 5): the punching bag and the
## sparring dummy in the home's training corner. Takes hits from the
## combat core: sways with the impact, carries posture that BREAKS
## (the dummy tips over and rights itself; the bag just swings
## harder), and remembers nothing between sessions - the corner is a
## practice space, not a fight.

const POSTURE_MAX := 10.0
const RECOVER_S := 1.4

var hp := 60.0
var posture := POSTURE_MAX
var tips := 0          # the posture breaks it has taken
var _sway := 0.0
var _broken := false
var _rec_t := 0.0
var _base_rot := 0.0


func _ready() -> void:
	add_to_group("train_target")
	_base_rot = rotation.z


func take_hit(damage: float, knockback: float, from_dir: Vector3,
		posture_damage: float) -> void:
	hp = maxf(hp - damage, 0.0)
	posture -= posture_damage
	_sway = clampf(knockback * 0.06 + _sway * 0.5, 0.0, 0.5)
	# the hit flash: scale pulse toward the blow
	if not _broken:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(1.04, 0.97, 1.04), 0.06)
		tw.tween_property(self, "scale", Vector3.ONE, 0.12)
	if posture <= 0.0 and not _broken:
		_break()
	Sound.play("punch_med_0", -3.0, randf_range(0.9, 1.1))


func _break() -> void:
	_broken = true
	tips += 1
	posture = 0.0
	_rec_t = 0.0
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", _base_rot - 1.35, 0.3)
	Sound.play("body_heavy_0", -3.0, 0.8)
	Haptics.fire("down")


func _process(delta: float) -> void:
	if _broken:
		_rec_t += delta
		if _rec_t >= RECOVER_S:
			_broken = false
			posture = POSTURE_MAX
			var tw := create_tween()
			tw.tween_property(self, "rotation:z", _base_rot, 0.5)
		return
	# the sway settles
	if _sway > 0.001:
		_sway = lerpf(_sway, 0.0, clampf(delta * 3.0, 0.0, 1.0))
		rotation.z = _base_rot + sin(_rec_t * 14.0) * _sway
		_rec_t += delta
	else:
		_rec_t = 0.0
	# posture heals slowly when left alone
	posture = minf(posture + delta * 0.8, POSTURE_MAX)
