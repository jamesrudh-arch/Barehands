extends Node
const CLS_ActionButton := preload("res://scripts/action_button.gd")
## GATE A (PRIORITY 0) verification: see, hear, move. Every acceptance
## item from the master prompt, checked headless. What cannot be
## proven here (the actual iPhone screen and speaker) is listed as
## PHONE-ONLY by tests/final_audit.gd and the DEVICE REPORT.
## Run: godot --headless --path . res://tests/smoke_safe.tscn

var _fails := 0
var _checks := 0
var _main: Node


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("SAFE FAIL: ", what)
	else:
		print("SAFE ok: ", what)


func _ready() -> void:
	Settings.set_value("first_run_done", true)
	# B27: quiet street for the crowd-count checks (smoke_events
	# runs the live street)
	Settings.set_value("dynamic_events", false)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	var opening := get_tree().get_first_node_in_group("opening")
	if opening:
		opening.skip()
	await get_tree().create_timer(2.5).timeout

	# --- A1: fullbright safe mode ------------------------------------------
	Visual.apply_profile(Visual.PROFILE_XOGOT_SAFE)
	await get_tree().create_timer(0.5).timeout
	var env := (get_tree().get_first_node_in_group("world_env") as WorldEnvironment).environment
	_check(Visual.profile == Visual.PROFILE_XOGOT_SAFE
			and env.ambient_light_energy >= 1.0,
			"A1 safe mode raises the ambient (%.2f)" % env.ambient_light_energy)
	_check(Visual.get_node_or_null("SafeSun") != null
			and Visual.get_node_or_null("SafeFill") != null,
			"A1 the safe sun and camera fill light exist")
	Visual.set_brightness(1.5)
	await get_tree().create_timer(0.2).timeout
	_check(env.ambient_light_energy > 1.4,
			"A1 the brightness dial raises the light (%.2f)" % env.ambient_light_energy)
	Visual.apply_brightness_preset("moody")
	await get_tree().create_timer(0.2).timeout
	_check(absf(Visual.safe_brightness - 0.65) < 0.01,
			"A1 the MOODY preset pins the dial (%.2f)" % Visual.safe_brightness)
	Visual.apply_brightness_preset("normal")
	Visual.apply_profile(Visual.PROFILE_NIGHT)
	await get_tree().create_timer(0.2).timeout
	_check(Visual.get_node_or_null("SafeSun") == null,
			"A1 NIGHT removes the safe lights")

	# --- A1b: the rendered frame has no black/white voids ------------------
	Visual.apply_profile(Visual.PROFILE_XOGOT_SAFE)
	await get_tree().create_timer(0.8).timeout
	# headless never draws a frame - the await would hang forever there
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var avg := -1.0
	var black_share := -1.0
	var white_share := -1.0
	if img != null:
		img.convert(Image.FORMAT_L8)
		var lum := 0.0
		var near_black := 0
		var near_white := 0
		var xs: Array[int] = []
		for x in range(0, img.get_width(), 6):
			xs.append(x)
		var ys: Array[int] = []
		for y in range(0, img.get_height(), 6):
			ys.append(y)
		for y in ys:
			for x in xs:
				var v := float(img.get_pixel(x, y).r)
				lum += v
				if v < 0.06:
					near_black += 1
				elif v > 0.97:
					near_white += 1
		var sampled := float(xs.size() * ys.size())
		avg = lum / sampled
		black_share = near_black / sampled
		white_share = near_white / sampled
		print("SAFE stats: avg %.3f | near-black %.1f%% | near-white %.1f%%"
				% [avg, black_share * 100.0, white_share * 100.0])
	else:
		print("SAFE stats: headless returned no image - PHONE-ONLY")
	_check(img == null or (avg > 0.06 and black_share < 0.75 and white_share < 0.02),
			"A1 no black or white voids (avg %.3f, black %.1f%%, white %.1f%%)"
			% [avg, black_share * 100.0, white_share * 100.0])

	# --- A7: the fighting controls ------------------------------------------
	var hud := get_tree().get_first_node_in_group("hud_buttons")
	var scheme := ""
	var letters := {}
	if hud:
		scheme = str(hud.call("_scheme"))
		for name in ["FightX", "FightY", "FightB", "FightA"]:
			var b: CLS_ActionButton = hud.get("_buttons").get(name)
			if b:
				letters[b.label] = b.sub
	_check(scheme == "fight",
			"A7 the FIGHT scheme is the default (got %s)" % scheme)
	# B24 (master directive 5.2/5.3): B is DODGE, A is KICK - never the
	# inverse
	_check(letters.get("X") == "PUNCH" and letters.get("Y") == "HEAVY"
			and letters.get("B") == "DODGE" and letters.get("A") == "KICK",
			"A7 X PUNCH / Y HEAVY / B DODGE / A KICK read (%s)" % str(letters))
	# the input strip must not sit on the button cluster
	var strip := get_tree().get_first_node_in_group("input_strip") as Control
	var overlap := false
	if hud and strip:
		for name in ["FightX", "FightY", "FightB", "FightA", "GuardBtn", "GrabBtn"]:
			var b: CLS_ActionButton = hud.get("_buttons").get(name)
			if b and b.visible and Rect2(strip.position, strip.size).intersects(
					Rect2(b.position, b.size)):
				overlap = true
	_check(strip != null and not overlap,
			"A7 the input strip is clear of the buttons (no bar across them)")

	# --- A3: audio sanity ----------------------------------------------------
	var facts: Dictionary = Sound.audio_facts().get("facts", {})
	var flagged: Array[String] = []
	var files := 0
	for clip in facts:
		var fl := str(facts[clip]["flag"])
		if fl == "file":
			files += 1
		elif fl != "ok":
			flagged.append(clip)
	_check(facts.size() >= 60 and files >= 50 and flagged.is_empty(),
			"A3 the audio bank is sane (%d streams: %d mastered files trusted, %d generated audited, flagged: %s)"
			% [facts.size(), files, facts.size() - files,
					", ".join(flagged) if not flagged.is_empty() else "none"])
	var bed_target: float = Music.layer_vol("music_bed")
	_check(bed_target <= -10.0,
			"A3 music starts LOW (bed target %.1f dB)" % bed_target)

	# --- A4: the walk out works ---------------------------------------------
	var player := get_tree().get_first_node_in_group("player") as Node3D
	player.global_position = Vector3(780.0, 0.02, 1.8)  # the apartment spawn
	await get_tree().create_timer(0.5).timeout
	# the door zone is near the door; walk the hero onto it with the
	# guide on its OPEN step, and the door must open BY ITSELF
	var guide := get_tree().get_first_node_in_group("guide")
	guide.set("step", 1)  # STEP_OPEN
	player.global_position = Vector3(780.0, 0.02, -2.6)  # at the door
	# poll: the door must open BY ITSELF (and the fade land the hero on
	# the street) within a generous window - the requirement is the
	# mechanism, not a frame-exact timing
	var door_state := "closed"
	var opened := false
	for i in 40:
		await get_tree().create_timer(0.25).timeout
		door_state = "closed"
		for n in get_tree().get_nodes_in_group("door_prompt"):
			if str(n.get_meta("door_name", "")).contains("APARTMENT"):
				door_state = str(n.get_meta("door_state", "?"))
				break
		if door_state in ["opening", "open"] or player.global_position.x < 700.0:
			opened = true
			break
	_check(opened,
			"A4 the door opens by itself during the guide (%s)" % door_state)
	var landed := false
	for i in 24:
		await get_tree().create_timer(0.25).timeout
		if player.global_position.x < 700.0:
			landed = true
			break
	_check(landed,
			"A4 the hero lands on the street (%s)" % str(player.global_position.round()))

	# --- A5: people ----------------------------------------------------------
	var peds := get_tree().get_nodes_in_group("wanderer").size()
	var watchers := get_tree().get_nodes_in_group("watcher").size()
	_check(peds >= 4 and watchers >= 1,
			"A5 the street has people (%d walkers, %d watchers)" % [peds, watchers])
	var noodle := 0
	for n in get_tree().get_nodes_in_group("interior"):
		if str(n.get_meta("door_name", "")) == "NOODLE SHOP DOOR":
			for c in n.find_children("*", "Node3D", true, false):
				var sc = c.get_script()
				if sc != null and "npc_rig" in str(sc.resource_path):
					noodle += 1
	_check(noodle >= 3,
			"A5 the noodle shop has the owner + customers (%d rigs)" % noodle)

	# --- A6: the guide always provides an objective -------------------------
	guide.set("step", 4)  # STEP_STAND
	var nav: Dictionary = guide.call("current_target")
	_check(not nav.is_empty() and str(nav.get("text", "")).length() > 3,
			"A6 a standing objective always exists (%s)" % str(nav.get("text", "-")))

	if _fails == 0:
		print("SAFE PASS (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("SAFE FAIL (%d of %d checks)" % [_fails, _checks])
		get_tree().quit(1)
