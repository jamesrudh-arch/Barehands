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

# 1) THE GLOW BREATHES AGAIN: it was halved during the milk saga,
#    but the milk's real killer (the DUSK sky lift) is dead - the
#    frame sits at 59 avg. Halation on lamps/signs returns without
#    re-floating anything.
patch("scripts/world/night_look.gd", [
("""	e.glow_intensity = 0.45
	e.glow_strength = 0.8""",
"""	e.glow_intensity = 0.6
	e.glow_strength = 0.85"""),
("""	e.set_glow_level(3, 0.45)
	e.set_glow_level(5, 0.2)""",
"""	e.set_glow_level(3, 0.6)
	e.set_glow_level(5, 0.3)"""),
])

# 2) THE NEON SMEARS: the pawn sign's magenta now bleeds onto the
#    wet street under it (the VLM's "cheap vertical smear of the
#    neon would sell it" - the lamp smears existed, the sign's
#    did not)
patch("scripts/areas/neighbourhood.gd", [
("""	# the neon sign
	_sign(front, label, glow, Vector3(0, 4.6, 0.2), 40)""",
"""	# the neon sign
	_sign(front, label, glow, Vector3(0, 4.6, 0.2), 40)
	# S5.17: the sign's colour bleeds onto the wet walk under it
	# (the sodium smears had lamps only; the neon pays too)
	CLS_NightLook.wet_streak(front,
			Vector3(0, 0.02, 2.6), glow, 4.5, 1.6)"""),
])

# 3) THE BLOBS: characters GROUND themselves - the contact-shadow
#    disc existed but nothing called it (the VLM: "characters and
#    kiosks float"). Under the hero and every enemy.
patch("scripts/player/hero.gd", [
("""	_anim = _find(_rig, AnimationPlayer) as AnimationPlayer""",
"""	# the grounding disc (S5.17): nobody called NightLook.blob -
#    every character floated. The hero anchors first.
	if _rig:
		var CLS_NightLook := preload(
				"res://scripts/world/night_look.gd")
		CLS_NightLook.blob(_rig, 0.6)
	_anim = _find(_rig, AnimationPlayer) as AnimationPlayer"""),
])
patch("scripts/npc/enemy.gd", [
("""func take_hit(damage: float, knockback: float, from_dir: Vector3,
		posture_damage: float) -> void:""",
"""## The grounding disc + the flash (S5.17): the blob anchors the
## body to the wet street; the flash pops on every landed blow.
func _ready() -> void:
	var CLS_NightLook := preload(
			"res://scripts/world/night_look.gd")
	CLS_NightLook.blob(self, 0.55)


func take_hit(damage: float, knockback: float, from_dir: Vector3,
		posture_damage: float) -> void:"""),
])
