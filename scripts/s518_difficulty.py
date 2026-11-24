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
# 1) THE CLIMB (missions.gd): every story mission finished lifts
#    the muscle's tier - hp +13%/tier, posture +9%/tier, and from
#    tier 2 (m3 done) every SECOND thug wears armor. The city
#    stops being one flat difficulty band.
# ============================================================
patch("scripts/missions/missions.gd", [
("""	var script := load("res://scripts/npc/enemy.gd") as GDScript
	for spec in _pending_spawn:
		var e: CharacterBody3D = script.new()
		e.position = spec.get("pos", Vector3.ZERO)
		e.rotation.y = float(spec.get("rot", 0.0))
		if spec.has("hp"):
			e.set("hp", float(spec["hp"]) * escalate)
		else:
			e.set("hp", float(e.get("hp")) * escalate)
		e.add_to_group("mission_spawn")
		scene.add_child(e)""",
"""	var script := load("res://scripts/npc/enemy.gd") as GDScript
	# S5.18 THE CLIMB: the tier counts finished STORY beats
	# (m0..m6); jobs and kinks ride the story's difficulty, not
	# their own. Tier 0 = the first night; tier 6 = the endgame.
	var tier := 0
	for i in 7:
		if WorldState.flag("mission_done:m%d" % i):
			tier += 1
	var idx := 0
	for spec in _pending_spawn:
		var e: CharacterBody3D = script.new()
		e.position = spec.get("pos", Vector3.ZERO)
		e.rotation.y = float(spec.get("rot", 0.0))
		if spec.has("hp"):
			e.set("hp", float(spec["hp"]) * escalate)
		else:
			e.set("hp", float(e.get("hp")) * escalate)
		# the tier lift (stacks with the endgame escalate branch)
		var thp: float = float(e.get("hp")) * (1.0 + 0.13 * tier)
		e.set("hp", thp)
		e.set("posture", float(e.get("posture")) \
				* (1.0 + 0.09 * tier))
		# ARMOR: authored in the spawn spec, or every second
		# thug once the story is half-turned (tier >= 3)
		if bool(spec.get("armored", false)) \\
				or (tier >= 3 and idx % 2 == 0):
			e.set_meta("armored", true)
		idx += 1
		e.add_to_group("mission_spawn")
		scene.add_child(e)"""),
("""		Log.info("Mission: muscle at %s (hp %.0f)" % [
				str(spec.get("pos", Vector3.ZERO)),
				float(e.get("hp"))])""",
"""		Log.info("Mission: muscle at %s (hp %.0f, tier %d%s)" % [
				str(spec.get("pos", Vector3.ZERO)),
				float(e.get("hp")), tier,
				" ARMORED" if e.get_meta("armored", false) else ""])"""),
])

# ============================================================
# 2) THE ARMORED ARCHETYPE (enemy.gd): a plate vest quad, more
#    hp/posture, hits harder, moves a shade slower - the late
#    game's answer to the player's rank-4 combo game.
# ============================================================
patch("scripts/npc/enemy.gd", [
("""const DAMAGE := 8.0""",
"""var DAMAGE := 8.0   # S5.18: the armored archetype scales it"""),
("""	# the grounding disc (S5.17): the blob anchors the body to the
	# wet street (NightLook.blob existed - nothing called it)
	preload("res://scripts/world/night_look.gd").blob(self, 0.55)""",
"""	# the grounding disc (S5.17): the blob anchors the body to the
	# wet street (NightLook.blob existed - nothing called it)
	preload("res://scripts/world/night_look.gd").blob(self, 0.55)
	# S5.18 THE ARMORED ARCHETYPE: plate reads before the first
	# punch lands - hp/posture up, damage up, a shade slower
	if get_meta("armored", false):
		hp *= 1.5
		posture *= 1.4
		DAMAGE *= 1.25
		max_speed *= 0.86
		var vest := MeshInstance3D.new()
		vest.name = "PlateVest"
		var bm := BoxMesh.new()
		bm.size = Vector3(0.44, 0.52, 0.34)
		var vm := StandardMaterial3D.new()
		vm.albedo_color = Color(0.28, 0.16, 0.13)
		vm.metallic = 0.35
		vm.roughness = 0.55
		bm.material = vm
		vest.mesh = bm
		vest.position = Vector3(0, 1.18, 0)
		add_child(vest)
		name += " [ARMORED]\"""".replace('\\"', '')),
])
