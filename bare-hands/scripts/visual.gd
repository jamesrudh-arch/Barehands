extends Node
## Visual profile + live visual state (B15). The VISUAL DEBUG panel
## drives everything through here; the game reads the multipliers at
## build time, and apply_*() pushes live changes to the groups.
##
## Two profiles:
##   NIGHT  - the desktop night as authored (glow on, full emission)
##   XOGOT SAFE - for Xogot/iOS Mobile-Metal: glow off, emission
##     capped, simple tonemap, minimal particles. Applied by default
##     on mobile so the phone boots safe; the panel can go back.

signal visual_changed

const PROFILE_NIGHT := "night"
const PROFILE_XOGOT_SAFE := "xogot_safe"

var profile := PROFILE_NIGHT
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
			emission_mult = 0.6
			rain_on = true
			rain_streak_width = 0.008
			splash_on = false
			decals_on = true
			outlines_on = true
			post_on = false   # no glow stack on Mobile-Metal
			shadows_on = false
			npcs_on = true
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
	_apply_all()


## Push every setting to the live scene. Safe to call any time; finds
## whatever exists and leaves the rest alone.
func _apply_all() -> void:
	apply_emission()
	apply_post()
	apply_rain()
	apply_decals()
	apply_outlines()
	apply_shadows()
	apply_npcs()
	apply_camera()
	visual_changed.emit()


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
	# the panel's POST toggle drives the glow stack directly; the
	# profile only decides where the game BOOTS (XOGOT SAFE = off)
	env.glow_enabled = post_on


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
	if cam is FollowCamera:
		(cam as FollowCamera).height = cam_height
		(cam as FollowCamera).distance = cam_distance
		(cam as FollowCamera).snap_framing()


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
		lines.append("env: tonemap=%d glow=%s intensity=%.2f bloom=%.2f hdr=%.2f" % [
				env.tonemap_mode, str(env.glow_enabled),
				env.glow_intensity, env.glow_bloom, env.glow_hdr_threshold])
		lines.append("env: fog=%s bg_energy=%.2f ambient_energy=%.2f" % [
				str(env.fog_enabled), env.background_energy_multiplier,
				env.ambient_light_energy])
	lines.append("visual: emission_mult=%.2f rain=%s streak=%.3f splash=%s" % [
			emission_mult, str(rain_on), rain_streak_width, str(splash_on)])
	lines.append("visual: decals=%s outlines=%s post=%s shadows=%s npcs=%s" % [
			str(decals_on), str(outlines_on), str(post_on),
			str(shadows_on), str(npcs_on)])
	lines.append("camera: height=%.2f distance=%.2f" % [cam_height, cam_distance])
	var hud := get_tree().get_first_node_in_group("hud")
	var buttons := 0
	if hud:
		for c in hud.get_children():
			if c is ActionButton and (c as ActionButton).visible:
				buttons += 1
	lines.append("touch: %d action buttons visible" % buttons)
	lines.append("difficulty: %s  fps: %d" % [
			Settings.value("difficulty"), Engine.get_frames_per_second()])
	return "\n".join(lines)
