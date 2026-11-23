#!/usr/bin/env python3
## S5.4 HEAT RESPONSE wiring: enemy metas (name/hp/label/tint) +
## the crime event, the Game mount, the hero's GRAB-at-fence, the
## HUD heat pips. Asserted replaces.
import sys

def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        if old not in s:
            print("MISS in %s:\n%s" % (path, old[:80]))
            sys.exit(1)
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)
    print("patched %s (%d hunks)" % (path, len(pairs)))

# ------------------------------------------------------------- enemy.gd
patch('scripts/npc/enemy.gd', [
# meta hooks at the top of _ready (name/hp), then label/tint after
# the rig exists
(
"""func _ready() -> void:
	add_to_group("npc")
	add_to_group("enemy")
	name = "Thug\"""",
"""func _ready() -> void:
	add_to_group("npc")
	add_to_group("enemy")
	# S5.4 meta hooks (THE COPY + future casts): one authoritative
	# body, per-instance identity
	name = str(get_meta("npc_name", "Thug"))
	hp = float(get_meta("hp_max", hp))"""
),
(
"""	var packed: PackedScene = load(RIG)
	if packed:
		_rig = packed.instantiate()
		_rig.name = "Rig"
		add_child(_rig)
		_skel = _find(_rig, Skeleton3D) as Skeleton3D""",
"""	var packed: PackedScene = load(RIG)
	if packed:
		_rig = packed.instantiate()
		_rig.name = "Rig"
		add_child(_rig)
		_skel = _find(_rig, Skeleton3D) as Skeleton3D
		if has_meta("tint"):
			_apply_tint(_rig, get_meta("tint") as Color)
	if has_meta("npc_label"):
		var tag := Label3D.new()
		tag.text = str(get_meta("npc_label"))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.pixel_size = 0.012
		tag.font_size = 44
		tag.modulate = Color(1.0, 0.85, 0.75, 0.9)
		tag.outline_size = 10
		tag.position = Vector3(0, 2.15, 0)
		add_child(tag)"""
),
# the crime event (police.gd's witness layer listens)
(
"""		WorldState.bump("heat", 4.0)  # the street saw it""",
"""		WorldState.bump("heat", 4.0)  # the street saw it
		WorldState.push_event("crime", {"pos": global_position,
				"base": 4.0, "who": name})"""
),
# the tint helper (the pedestrian law: OVERRIDE the mesh instance -
# surface_set_material mutates the SHARED mesh)
(
"""func _find(root_n: Node, what) -> Node:""",
"""## Per-instance clothing tint (probe law from the pedestrians).
func _apply_tint(rig: Node, tint: Color) -> void:
	if rig == null or tint == Color.WHITE:
		return
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s_idx in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s_idx)
			if mat is StandardMaterial3D:
				var clone: StandardMaterial3D = \\
						(mat as StandardMaterial3D).duplicate()
				clone.albedo_color = tint
				(mi as MeshInstance3D).set_surface_override_material(
						s_idx, clone)


func _find(root_n: Node, what) -> Node:"""
),
])

# -------------------------------------------------------------- game.gd
patch('scripts/core/game.gd', [
(
"""var _missions: Node = null
var _hud: CanvasLayer = null""",
"""var _missions: Node = null
var _hud: CanvasLayer = null
var _police: Node = null"""
),
(
"""	if _hud == null or not is_instance_valid(_hud):
		_hud = load("res://scripts/ui/hud.gd").new()""",
"""	if _police == null or not is_instance_valid(_police):
		_police = load("res://scripts/core/police.gd").new()
		add_child(_police)
	if _hud == null or not is_instance_valid(_hud):
		_hud = load("res://scripts/ui/hud.gd").new()"""
),
])

# ------------------------------------------------------------- hero.gd
patch('scripts/player/hero.gd', [
(
"""			if action == "draw" and _gun:
				_gun.toggle()""",
"""			if action == "draw" and _gun:
				_gun.toggle()
			elif action == "grab":
				# GRAB at the fence pays the scrub (police.gd owns
				# the law; anywhere else it stays GRAB)
				var paid := false
				for p in get_tree().get_nodes_in_group("police"):
					if p.try_fence(self):
						paid = true
						break
				if not paid:
					face_action.emit(action)"""
),
])

# -------------------------------------------------------------- hud.gd
s = open('scripts/ui/hud.gd').read()
old = """	root.add_child(_rank_label)"""
assert old in s
s = s.replace(old, """	root.add_child(_rank_label)
	# the HEAT pips (top-left under the rank; the phone LEDGER has
	# the number - this is the glance read)
	_heat_pips = []
	for i in 8:
		var pip := ColorRect.new()
		pip.name = "HeatPip%d" % i
		pip.position = Vector2(24 + i * 13, 68)
		pip.size = Vector2(9, 14)
		pip.color = Color(0.95, 0.65, 0.25) if i < 2 \\
				else (Color(0.95, 0.45, 0.2) if i < 5 \\
				else Color(0.9, 0.2, 0.25))
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.visible = false
		root.add_child(pip)
		_heat_pips.append(pip)"""
)
old2 = "var _gun: Node = null"
assert old2 in s
s = s.replace(old2, "var _gun: Node = null\nvar _heat_pips: Array = []")
old3 = """	var combat := _combat()"""
assert old3 in s
s = s.replace(old3, """	# the heat glance read
	var heat := float(WorldState.get_value("heat", 0.0))
	var n_pips := clampi(ceili(heat), 0, 8)
	for i in 8:
		_heat_pips[i].visible = i < n_pips
	var combat := _combat()"""
)
open('scripts/ui/hud.gd','w').write(s)
print("hud heat pips wired")
print("ALL WIRED")
