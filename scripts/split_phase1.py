#!/usr/bin/env python3
"""Produce the Phase-1-only snapshot of player.gd (mannequin animation refs)
for a clean phase split commit; the Phase-2 version is kept in /tmp."""
import pathlib

P = pathlib.Path("/home/z/my-project/bare-hands/scripts/player.gd")
s = P.read_text()
pathlib.Path("/tmp/player_phase2.gd").write_text(s)

s = s.replace(
    "@onready var _rig: HeroRig = $Body/Hero",
    "@onready var _anim: AnimationPlayer = $Body/Mannequin/AnimationPlayer")
s = s.replace(
    "\t_rig._velocity_fn = func() -> Vector3: return velocity  # drives the coat sway\n", "")
s = s.replace("_rig.play(", "_play(")
s = s.replace("_rig.set_speed(1.8)", "_anim.speed_scale = 1.8")
s = s.replace("_rig.set_speed(clampf(speed / 2.2, 0.7, 1.7))",
              "_anim.speed_scale = clampf(speed / 2.2, 0.7, 1.7)")
s = s.replace("_rig.set_speed(clampf(speed / 5.6, 0.75, 1.5))",
              "_anim.speed_scale = clampf(speed / 5.6, 0.75, 1.5)")
s = s.replace("_rig.current()", "_anim.current_animation")
s = s.replace("_rig.is_playing()", "_anim.is_playing()")
s += """

func _play(anim_name: String, blend: float = 0.25, speed := 1.0) -> void:
	if _anim.current_animation != anim_name:
		_anim.speed_scale = 1.0
		_anim.play(anim_name, blend)
		_anim.speed_scale = speed
"""
P.write_text(s)
print("phase-1 snapshot written")
