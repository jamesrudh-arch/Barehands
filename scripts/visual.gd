extends Node
const CLS_ActionButton := preload("res://scripts/action_button.gd")
const CLS_FollowCamera := preload("res://scripts/camera_follow.gd")
## Visual profile + live visual state (B15). The VISUAL DEBUG panel
## drives everything through here; the game reads the multipliers at
## build time, and apply_*() pushes live changes to the groups.
##
## Two profiles:
##   NIGHT  - the desktop night as authored (glow on, full emission)
##   XOGOT SAFE - Gate A FULLBRIGHT SAFE MODE: strong even lighting
##     (a sun + a camera fill light + raised warm ambient) so no
##     playable surface can render black on any device, emission
##     capped, simple tonemap, minimal particles. Applied by default
##     on mobile so the phone boots VISIBLE; BRIGHT / NORMAL / MOODY
##     presets and a live brightness slider (0.5..2.0) tune it.

signal visual_changed

const PROFILE_NIGHT := "night"
const PROFILE_XOGOT_SAFE := "xogot_safe"

var profile := PROFILE_NIGHT
var safe_brightness := 1.0        # Gate A: the safe-mode brightness dial
var emission_mult := 1.0        # multiplies every neon/window energy
var rain_on := true
var rain_streak_width := 0.008  # metres; thin streaks, not squares
var splash_on := false          # off unless the tier (and profile) says
var decals_on := true
var outlines_on := true
var post_on := true             # glow + adjustments
var shadows_on := true
var npcs_on := true
var cam_height := 2.8
var cam_distance := 6.0
# B18: the glow stack each profile APPLIES. The B15 SAFE preset turned
# glow off and halved emission - on the phone that read as a black
# street (owner photo, 2026-11-21). The new SAFE keeps a modest glow
# and full emission; the sign materials themselves are capped at the
# source now, so nothing needs the dimmer.
var glow_threshold := 1.45
var glow_intensity := 0.50
var glow_bloom := 0.05
var tonemap_white := 6.0        # the exposure ceiling (Mobile-safe: 4)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("mobile"):
		apply_profile(PROFILE_XOGOT_SAFE)
		Log.info("visual: mobile device - XOGOT SAFE profile baked in")


## The baked-safe values. Called at boot on mobile and by the panel's
## XOGOT SAFE button; the NIGHT profile restores the authored look.
func apply_profile(p: String) -> void:
	profile = p
	match p:
		PROFILE_XOGOT_SAFE:
			emission_mult = 1.0
			rain_on = true
			rain_streak_width = 0.008
			splash_on = false
			decals_on = true
			outlines_on = true
			post_on = true    # B18: modest glow ON - the street must read
			shadows_on = false
			npcs_on = true
			glow_threshold = 1.02
			glow_intensity = 0.38
			glow_bloom = 0.04
			tonemap_white = 4.0
		PROFILE_NIGHT:
			emission_mult = 1.0
			rain_on = true
			rain_streak_width = 0.008
			splash_on = true
			decals_on = true
			outlines_on = true
			post_on = true
			shadows_on = true
			npcs_on = true
			glow_threshold = 1.45
			glow_intensity = 0.50
			glow_bloom = 0.05
			tonemap_white = 6.0
	_apply_all()


## Gate A: the brightness presets. BRIGHT lifts every safe light,
## MOODY dims them toward the authored night (never below readability).
func apply_brightness_preset(id: String) -> void:
	match id:
		"bright":
			set_brightness(1.5)
		"normal":
			set_brightness(1.0)
		"moody":
			set_brightness(0.65)


## The live brightness dial (Visual Debug + Settings sliders).
func set_brightness(b: float) -> void:
	safe_brightness = clampf(b, 0.5, 2.0)
	if profile == PROFILE_XOGOT_SAFE:
		_apply_safe_lights()
	visual_changed.emit()


func _apply_all() -> void:
	apply_emission()
	apply_post()
	apply_rain()
	apply_decals()
	apply_outlines()
	apply_shadows()
	apply_npcs()
	apply_camera()
	_apply_safe_lights()
	visual_changed.emit()


## Gate A FULLBRIGHT: a sun, a camera fill light and raised warm
## ambient - the guarantee that no playable surface can render black,
## whatever a specific GPU does with the authored night. Everything
## scales with safe_brightness; NIGHT removes the safe lights again.
func _apply_safe_lights() -> void:
	var env := _env()
	var scene := get_tree().current_scene if is_inside_tree() else null
	if env != null:
		if profile == PROFILE_XOGOT_SAFE:
			# warm neutral ambient, lifted by the dial
			env.ambient_light_color = Color(0.5, 0.48, 0.45)
			env.ambient_light_energy = 1.35 * safe_brightness
		else:
			env.ambient_light_color = Color(0.2, 0.19, 0.185)
			env.ambient_light_energy = 1.0
	var sun := get_node_or_null("/root/Visual/SafeSun") as DirectionalLight3D
	var fill := get_node_or_null("/root/Visual/SafeFill") as OmniLight3D
	if profile == PROFILE_XOGOT_SAFE:
		if sun == null:
			sun = DirectionalLight3D.new()
			sun.name = "SafeSun"
			sun.rotation = Vector3(-0.9, 0.4, 0)
			add_child(sun)
		sun.light_color = Color(1.0, 0.96, 0.9)
		sun.light_energy = 1.05 * safe_brightness
		sun.shadow_enabled = false
		if fill == null:
			fill = OmniLight3D.new()
			fill.name = "SafeFill"
			fill.omni_range = 26.0
			add_child(fill)
		fill.light_color = Color(1.0, 0.9, 0.78)
		fill.light_energy = 0.75 * safe_brightness
		fill.shadow_enabled = false
		# the fill rides the camera so characters are never fully dark
		var cam := get_tree().get_first_node_in_group("camera") as Node3D
		if cam:
			fill.global_position = cam.global_position - cam.global_transform.basis.z * 3.0
	else:
		if sun:
			sun.queue_free()
		if fill:
			fill.queue_free()


## The camera fill light follows the camera every frame (cheap).
func _process(_delta: float) -> void:
	if profile != PROFILE_XOGOT_SAFE:
		return
	var fill := get_node_or_null("SafeFill") as OmniLight3D
	var cam := get_tree().get_first_node_in_group("camera") as Node3D
	if fill and cam:
		fill.global_position = cam.global_position - cam.global_transform.basis.z * 3.0


func _env() -> Environment:
	var we := get_tree().get_first_node_in_group("world_env") as WorldEnvironment
	if we:
		return we.environment
	return null


func apply_emission() -> void:
	# neon signs multiply their flicker base; window quads carry
	# their authored energy in "base_energy" metadata
	for n in get_tree().get_nodes_in_group("neon"):
		n.set_meta("emission_mult", emission_mult)
	for n in get_tree().get_nodes_in_group("emissive_window"):
		var mi := n as MeshInstance3D
		if mi and mi.has_meta("base_energy"):
			var mat: StandardMaterial3D = mi.mesh.surface_get_material(0)
			if mat:
				mat.emission_energy_multiplier = \
						float(mi.get_meta("base_energy")) * emission_mult


func apply_post() -> void:
	var env := _env()
	if env == null:
		return
	# B18: the profile owns the whole glow stack + the exposure ceiling,
	# so XOGOT SAFE is a real look, not just "glow off"
	env.glow_enabled = post_on and glow_intensity > 0.001
	env.glow_intensity = glow_intensity
	env.glow_bloom = glow_bloom
	env.glow_hdr_threshold = glow_threshold
	env.tonemap_white = tonemap_white


func apply_rain() -> void:
	for layer in get_tree().get_nodes_in_group("rain_layer"):
		layer.call("visual_apply", rain_on, rain_streak_width, splash_on)


func apply_decals() -> void:
	for d in get_tree().get_nodes_in_group("decal"):
		(d as Node3D).visible = decals_on


func apply_outlines() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("set_edge_glow"):
			e.call("set_edge_glow", outlines_on)


func apply_shadows() -> void:
	for light in get_tree().get_nodes_in_group("street_lights"):
		if light is Light3D:
			(light as Light3D).shadow_enabled = shadows_on


func apply_npcs() -> void:
	for group in ["wanderer", "cast_npc", "trainer"]:
		for n in get_tree().get_nodes_in_group(group):
			if n is Node3D:
				(n as Node3D).visible = npcs_on


func apply_camera() -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam is CLS_FollowCamera:
		(cam as CLS_FollowCamera).height = cam_height
		(cam as CLS_FollowCamera).distance = cam_distance
		(cam as CLS_FollowCamera).snap_framing()


## Everything the COPY SETTINGS button shows, one copyable block.
func dump_settings() -> String:
	var env := _env()
	var lines: Array[String] = []
	lines.append("== BARE HANDS VISUAL SETTINGS ==")
	lines.append("profile: %s" % profile)
	lines.append("renderer: %s / adapter: %s" % [
			ProjectSettings.get_setting("rendering/renderer/rendering_method"),
			RenderingServer.get_video_adapter_name()])
	lines.append("window: %s  safe_area: %s  orientation: %s" % [
			get_window().size, DisplayServer.get_display_safe_area(),
			DisplayServer.screen_get_orientation()])
	lines.append("quality tier: %s (override %s)  scale_3d: %.2f" % [
			Quality.tier, Quality.override,
			get_viewport().scaling_3d_scale])
	if env:
		lines.append("env: tonemap=%d white=%.2f glow=%s intensity=%.2f bloom=%.2f hdr=%.2f" % [
				env.tonemap_mode, env.tonemap_white, str(env.glow_enabled),
				env.glow_intensity, env.glow_bloom, env.glow_hdr_threshold])
		lines.append("env: fog=%s bg_energy=%.2f ambient_energy=%.2f" % [
				str(env.fog_enabled), env.background_energy_multiplier,
				env.ambient_light_energy])
	lines.append("hdr_2d: %s" % str(ProjectSettings.get_setting(
			"rendering/viewport/hdr_2d", false)))
	lines.append("visual: emission_mult=%.2f rain=%s streak=%.3f splash=%s" % [
			emission_mult, str(rain_on), rain_streak_width, str(splash_on)])
	lines.append("visual: decals=%s outlines=%s post=%s shadows=%s npcs=%s" % [
			str(decals_on), str(outlines_on), str(post_on),
			str(shadows_on), str(npcs_on)])
	# Gate A safe mode: the fullbright facts the DEVICE REPORT needs
	lines.append("safe_mode: profile=%s brightness=%.2f sun=%s fill=%s" % [
			profile, safe_brightness,
			str(get_node_or_null("SafeSun") != null),
			str(get_node_or_null("SafeFill") != null)])
	lines.append("camera: height=%.2f distance=%.2f" % [cam_height, cam_distance])
	var hud := get_tree().get_first_node_in_group("hud")
	var buttons := 0
	if hud:
		for c in hud.get_children():
			if c is CLS_ActionButton and (c as CLS_ActionButton).visible:
				buttons += 1
	lines.append("touch: %d action buttons visible" % buttons)
	lines.append("difficulty: %s  fps: %d" % [
			Settings.value("difficulty"), Engine.get_frames_per_second()])
	return "\n".join(lines)
