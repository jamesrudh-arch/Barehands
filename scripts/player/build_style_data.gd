extends SceneTree

## THE STYLE DATA BUILDER (rebuild step 5): writes data/attacks/*.tres
## + data/styles/*.tres from the tables below. Run once headless:
##   godot --headless --path . -s res://scripts/player/build_style_data.gd
## The .tres files are committed; this builder is the regen path when
## the tables change. Five styles, one truth per attack.

const AD := preload("res://scripts/data/attack_data.gd")
const SD := preload("res://scripts/data/style_data.gd")

## clip shorthands (library prefixes added here)
const C := {
	"punch": "combat/Melee_Unarmed_Attack_Punch_A",
	"kick": "combat/Melee_Unarmed_Attack_Kick",
	"chop": "combat/Melee_1H_Attack_Chop",
	"jump_chop": "combat/Melee_1H_Attack_Jump_Chop",
	"diag": "combat/Melee_1H_Attack_Slice_Diagonal",
	"horiz": "combat/Melee_1H_Attack_Slice_Horizontal",
	"stab": "combat/Melee_1H_Attack_Stab",
	"chop2h": "combat/Melee_2H_Attack_Chop",
	"slice2h": "combat/Melee_2H_Attack_Slice",
	"spin": "combat/Melee_2H_Attack_Spin",
	"spin_f": "combat/Melee_2H_Attack_Spinning",
	"stab2h": "combat/Melee_2H_Attack_Stab",
	"dw_chop": "combat/Melee_Dualwield_Attack_Chop",
	"dw_slice": "combat/Melee_Dualwield_Attack_Slice",
	"dw_stab": "combat/Melee_Dualwield_Attack_Stab",
	"block_atk": "combat/Melee_Block_Attack",
	"throw": "ambient/Throw",
	"stance_unarmed": "combat/Melee_Unarmed_Idle",
	"stance_2h": "combat/Melee_2H_Idle",
	"stance_block": "combat/Melee_Blocking",
	"stance_sway": "ambient/Idle_B",
}


func _attack(id: String, clip: String, d: Dictionary) -> Resource:
	var a := AD.new()
	a.id = id
	a.clip = StringName(C.get(clip, clip))
	for k in d:
		a.set(k, d[k])
	ResourceSaver.save(a, "res://data/attacks/%s.tres" % id)
	return a


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/attacks")
	DirAccess.make_dir_recursive_absolute("res://data/styles")

	# --- BRAWLER: the street basics - balanced, honest, fast recovery
	var p1 := _attack("brawler_p1", "punch", {
		"damage": 4.0, "startup_s": 0.10, "active_s": 0.08,
		"recover_s": 0.16, "cancel_from_s": 0.14, "knockback": 1.2,
		"meter_gain": 6.0, "haptic": "light"})
	var p2 := _attack("brawler_p2", "punch", {
		"damage": 5.0, "startup_s": 0.12, "active_s": 0.08,
		"recover_s": 0.18, "cancel_from_s": 0.16, "knockback": 1.6,
		"meter_gain": 7.0, "haptic": "light"})
	var p3 := _attack("brawler_p3", "horiz", {
		"damage": 8.0, "startup_s": 0.16, "active_s": 0.10,
		"recover_s": 0.24, "cancel_from_s": 0.22, "knockback": 2.6,
		"meter_gain": 10.0, "haptic": "heavy", "posture_damage": 2.0})
	var bh := _attack("brawler_heavy", "chop", {
		"damage": 12.0, "startup_s": 0.24, "active_s": 0.12,
		"recover_s": 0.30, "knockback": 4.0, "meter_gain": 12.0,
		"haptic": "heavy", "posture_damage": 2.5})
	var bk := _attack("brawler_kick", "kick", {
		"damage": 9.0, "startup_s": 0.18, "active_s": 0.10,
		"recover_s": 0.26, "knockback": 3.4, "reach": 2.0,
		"meter_gain": 10.0, "haptic": "heavy", "posture_damage": 2.0})
	var bf := _attack("brawler_finisher", "chop2h", {
		"damage": 18.0, "startup_s": 0.30, "active_s": 0.14,
		"recover_s": 0.40, "knockback": 6.0, "meter_gain": 0.0,
		"haptic": "super", "posture_damage": 4.0})

	# --- KICKBOXING: the legs carry it - the kick is the signature,
	#     hands are fast pitter-patter, the flying knee is the heavy
	var k1 := _attack("kick_p1", "punch", {
		"damage": 3.0, "startup_s": 0.08, "active_s": 0.07,
		"recover_s": 0.12, "cancel_from_s": 0.10, "knockback": 0.8,
		"meter_gain": 5.0})
	var k2 := _attack("kick_p2", "punch", {
		"damage": 4.0, "startup_s": 0.10, "active_s": 0.07,
		"recover_s": 0.13, "cancel_from_s": 0.11, "knockback": 1.0,
		"meter_gain": 6.0})
	var k3 := _attack("kick_p3", "stab", {
		"damage": 6.0, "startup_s": 0.12, "active_s": 0.08,
		"recover_s": 0.16, "cancel_from_s": 0.14, "knockback": 1.4,
		"meter_gain": 7.0})
	var kh := _attack("kick_heavy", "jump_chop", {
		"damage": 14.0, "startup_s": 0.30, "active_s": 0.14,
		"recover_s": 0.36, "knockback": 5.0, "reach": 2.1,
		"meter_gain": 14.0, "haptic": "super", "posture_damage": 3.0})
	var kk := _attack("kick_kick", "kick", {
		"damage": 13.0, "startup_s": 0.16, "active_s": 0.12,
		"recover_s": 0.24, "knockback": 4.6, "reach": 2.3,
		"meter_gain": 13.0, "haptic": "heavy", "posture_damage": 2.5})
	var kf := _attack("kick_finisher", "jump_chop", {
		"damage": 20.0, "startup_s": 0.34, "active_s": 0.16,
		"recover_s": 0.44, "knockback": 7.0, "reach": 2.2,
		"meter_gain": 0.0, "haptic": "super", "posture_damage": 4.0})

	# --- GRAPPLING: close, patient - short strikes that chew POSTURE,
	#     the throw is the heavy, the slam is the ender
	var g1 := _attack("grap_p1", "block_atk", {
		"damage": 3.0, "startup_s": 0.12, "active_s": 0.08,
		"recover_s": 0.18, "knockback": 0.4, "reach": 1.4,
		"meter_gain": 6.0, "posture_damage": 2.0})
	var g2 := _attack("grap_p2", "dw_stab", {
		"damage": 4.0, "startup_s": 0.14, "active_s": 0.08,
		"recover_s": 0.20, "knockback": 0.5, "reach": 1.4,
		"meter_gain": 7.0, "posture_damage": 2.2})
	var g3 := _attack("grap_p3", "dw_slice", {
		"damage": 5.0, "startup_s": 0.16, "active_s": 0.09,
		"recover_s": 0.22, "knockback": 0.6, "reach": 1.5,
		"meter_gain": 8.0, "posture_damage": 2.5})
	var gh := _attack("grap_heavy", "throw", {
		"damage": 15.0, "startup_s": 0.26, "active_s": 0.12,
		"recover_s": 0.34, "knockback": 3.0, "reach": 1.5,
		"meter_gain": 15.0, "haptic": "super", "posture_damage": 5.0})
	var gk := _attack("grap_kick", "kick", {
		"damage": 7.0, "startup_s": 0.20, "active_s": 0.09,
		"recover_s": 0.28, "knockback": 1.8, "reach": 1.9,
		"meter_gain": 8.0})
	var gf := _attack("grap_finisher", "stab2h", {
		"damage": 22.0, "startup_s": 0.32, "active_s": 0.15,
		"recover_s": 0.42, "knockback": 2.0, "reach": 1.6,
		"meter_gain": 0.0, "haptic": "super", "posture_damage": 6.0})

	# --- DRUNKEN: looks like luck, lands like a piano - long windups,
	#     wild arcs, huge payoff, the sway stance sells it
	var d1 := _attack("drunk_p1", "diag", {
		"damage": 6.0, "startup_s": 0.20, "active_s": 0.10,
		"recover_s": 0.22, "cancel_from_s": 0.20, "knockback": 2.0,
		"meter_gain": 8.0})
	var d2 := _attack("drunk_p2", "dw_chop", {
		"damage": 7.0, "startup_s": 0.22, "active_s": 0.10,
		"recover_s": 0.24, "cancel_from_s": 0.22, "knockback": 2.2,
		"meter_gain": 9.0})
	var d3 := _attack("drunk_p3", "dw_slice", {
		"damage": 9.0, "startup_s": 0.24, "active_s": 0.12,
		"recover_s": 0.26, "knockback": 2.8,
		"meter_gain": 11.0, "haptic": "heavy"})
	var dh := _attack("drunk_heavy", "spin", {
		"damage": 16.0, "startup_s": 0.34, "active_s": 0.18,
		"recover_s": 0.34, "knockback": 5.5, "arc": 1.6,
		"meter_gain": 16.0, "haptic": "super", "posture_damage": 3.5})
	var dk := _attack("drunk_kick", "jump_chop", {
		"damage": 11.0, "startup_s": 0.26, "active_s": 0.12,
		"recover_s": 0.30, "knockback": 4.0, "reach": 2.0,
		"meter_gain": 11.0, "haptic": "heavy"})
	var df := _attack("drunk_finisher", "spin_f", {
		"damage": 24.0, "startup_s": 0.40, "active_s": 0.20,
		"recover_s": 0.46, "knockback": 8.0, "arc": 1.8,
		"meter_gain": 0.0, "haptic": "super", "posture_damage": 5.0})

	# --- WEAPON: something in the hand changes everything - the pipe
	#     swings hit harder, slower, at longer reach
	var w1 := _attack("weap_p1", "horiz", {
		"damage": 7.0, "startup_s": 0.16, "active_s": 0.10,
		"recover_s": 0.24, "cancel_from_s": 0.22, "knockback": 2.2,
		"reach": 2.1, "meter_gain": 8.0, "haptic": "heavy"})
	var w2 := _attack("weap_p2", "diag", {
		"damage": 8.0, "startup_s": 0.18, "active_s": 0.10,
		"recover_s": 0.26, "cancel_from_s": 0.24, "knockback": 2.6,
		"reach": 2.1, "meter_gain": 9.0, "haptic": "heavy"})
	var w3 := _attack("weap_p3", "slice2h", {
		"damage": 11.0, "startup_s": 0.22, "active_s": 0.12,
		"recover_s": 0.30, "knockback": 3.6, "reach": 2.2,
		"meter_gain": 11.0, "haptic": "heavy", "posture_damage": 2.5})
	var wh := _attack("weap_heavy", "chop2h", {
		"damage": 17.0, "startup_s": 0.30, "active_s": 0.14,
		"recover_s": 0.36, "knockback": 5.0, "reach": 2.2,
		"meter_gain": 15.0, "haptic": "super", "posture_damage": 3.5})
	var wk := _attack("weap_kick", "kick", {
		"damage": 8.0, "startup_s": 0.18, "active_s": 0.10,
		"recover_s": 0.26, "knockback": 3.2, "reach": 2.0,
		"meter_gain": 8.0})
	var wf := _attack("weap_finisher", "spin_f", {
		"damage": 26.0, "startup_s": 0.38, "active_s": 0.18,
		"recover_s": 0.44, "knockback": 8.5, "reach": 2.4, "arc": 1.7,
		"meter_gain": 0.0, "haptic": "super", "posture_damage": 5.0})

	# --- the styles
	_style("brawler", "BRAWLER", "stance_unarmed",
			"The street basics: honest hands, fast recovery.",
			[p1, p2, p3, bh, bk, bf])
	_style("kickboxing", "KICKBOXING", "stance_unarmed",
			"The legs carry it: the kick is the signature.",
			[k1, k2, k3, kh, kk, kf])
	_style("grappling", "GRAPPLING", "stance_block",
			"Clinch and grind: short strikes that chew posture, the throw ends it.",
			[g1, g2, g3, gh, gk, gf])
	_style("drunken", "DRUNKEN", "stance_sway",
			"Looks like luck, lands like a piano.",
			[d1, d2, d3, dh, dk, df])
	_style("weapon", "WEAPON", "stance_2h",
			"Something in the hand changes everything.",
			[w1, w2, w3, wh, wk, wf])
	print("STYLE DATA BUILT: 30 attacks, 5 styles")
	quit(0)


func _style(id: String, display: String, stance: String, blurb: String,
		attacks: Array) -> void:
	var s := SD.new()
	s.id = id
	s.display = display
	s.stance_clip = StringName(C.get(stance, stance))
	s.blurb = blurb
	s.punch_1 = attacks[0]
	s.punch_2 = attacks[1]
	s.punch_3 = attacks[2]
	s.heavy = attacks[3]
	s.kick = attacks[4]
	s.finisher = attacks[5]
	ResourceSaver.save(s, "res://data/styles/%s.tres" % id)
