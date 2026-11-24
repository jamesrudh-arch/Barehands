extends Node

## THE MATERIAL LIBRARY (overhaul S5.2): the city's shared PBR
## materials, loaded once, instanced per surface with the UV scale
## matched to the surface size (one material def, every slab its own
## tile density - a 100 m road and a 2 m curb both read right).
## Sources: Polyhaven CC0 (see assets/v2/pbr/LICENSE.txt).
## Mobile law: 1k JPGs, one shared material per family, normal maps
## only where the light reads them (floors + close facades).

const DIR := "res://assets/v2/pbr/"

const DEFS := {
	# name: [diffuse, normal, roughness(0-1), metallic, tile_m]
	"asphalt": [DIR + "asphalt_diff.jpg", DIR + "asphalt_nor.jpg",
			0.08, 0.25, 3.5],   # WET: dark diffuse + hot specular
	"concrete": [DIR + "concrete_diff.jpg", DIR + "concrete_nor.jpg",
			0.8, 0.0, 2.5],
	"brick": [DIR + "brick_diff.jpg", DIR + "brick_nor.jpg",
			0.85, 0.0, 3.0],
	"corrugated": [DIR + "corrugated_diff.jpg",
			DIR + "corrugated_nor.jpg", 0.55, 0.6, 2.0],
	"container": [DIR + "container_diff.jpg",
			DIR + "container_nor.jpg", 0.6, 0.3, 2.5],
}

static var _base: Dictionary = {}


## A fresh material instance for a surface of the given world size
## (its uv1_scale tiles the texture at the def's density). `name`
## falls back to plain white if the texture set failed to load.
## Box-aware surface: uv scaled PER AXIS so walls tile at true
## world scale on every face (surface() assumes a ground plane -
## one axis dominates and wall faces came out with giant bricks).
static func surface_box(name: String, world_size: Vector3) -> StandardMaterial3D:
	var mat := surface(name, world_size)
	var def: Array = DEFS.get(name, [])
	var tile: float = def[4] if def.size() > 4 else 0.0
	if tile > 0.0:
		mat.uv1_scale = Vector3(
				maxf(world_size.x, 0.01) / tile,
					maxf(world_size.y, 0.01) / tile,
					maxf(world_size.z, 0.01) / tile)
	return mat

static func surface(name: String, world_size: Vector3) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var def: Array = DEFS.get(name, [])
	if def.is_empty():
		mat.albedo_color = Color(0.5, 0.5, 0.5)
		return mat
	var diff: Texture2D = load(def[0])
	if diff == null:
		mat.albedo_color = Color(0.5, 0.5, 0.5)
		return mat
	mat.albedo_texture = diff
	var nor: Texture2D = load(def[1])
	if nor != null:
		mat.normal_enabled = true
		mat.normal_texture = nor
	mat.roughness = def[2]
	mat.metallic = def[3]
	# the night-exposure lift: Polyhaven maps are photographed mid-
	# grey; at night they read as void. Lift the albedo (colour
	# multiplies the map) so lamp light has something to bounce off.
	# S5.16 MILK LAW: the art pass now lights the street (pools,
	# neon, glow) - the 1.45 lift was authored when nothing did, and
	# it floated the frame to daylight. 1.15 keeps faces readable.
	# Asphalt goes DARK: its hot specular then reads as WET, not as
	# grey wash.
	var lift := 1.15
	if name == "asphalt":
		lift = 0.55
	mat.albedo_color = Color(lift, lift, lift * 1.04)
	var tile: float = def[4]
	if tile > 0.0 and world_size.x > 0.0 and world_size.z > 0.0:
		# tile the plane so the texture repeats every `tile` metres
		mat.uv1_scale = Vector3(maxf(world_size.x, world_size.z)
				/ tile, 1.0,
				maxf(world_size.x, world_size.z) / tile)
		mat.uv1_triplanar = true  # boxes tile on every face honestly
	return mat


## The base material (shared, unscaled) - for props that carry
## their own sensible UVs.
static func base(name: String) -> StandardMaterial3D:
	if _base.has(name):
		return _base[name]
	var def: Array = DEFS.get(name, [])
	var mat := StandardMaterial3D.new()
	if not def.is_empty():
		var diff: Texture2D = load(def[0])
		if diff != null:
			mat.albedo_texture = diff
		var nor: Texture2D = load(def[1])
		if nor != null:
			mat.normal_enabled = true
			mat.normal_texture = nor
		mat.roughness = def[2]
		mat.metallic = def[3]
	_base[name] = mat
	return mat
