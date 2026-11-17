extends MeshInstance3D
## Neon sign behaviour: steady glow, flicker, buzz or a broken sign that
## mostly stays dark and strobes. Duplicates the material at startup so
## every sign flickers independently.

@export_enum("steady", "flicker", "buzz", "broken") var style := "flicker"

var _mat: StandardMaterial3D
var _base := 3.5
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	var mi := self as MeshInstance3D
	if mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return
	var m: Material = mi.mesh.surface_get_material(0)
	if m == null or m is not StandardMaterial3D:
		return
	mi.mesh = mi.mesh.duplicate()
	_mat = (m as StandardMaterial3D).duplicate()
	mi.mesh.surface_set_material(0, _mat)
	_base = _mat.emission_energy_multiplier
	_seed = randf() * 100.0
	set_process(true)


func _process(delta: float) -> void:
	if _mat == null:
		return
	_t += delta
	match style:
		"steady":
			_mat.emission_energy_multiplier = _base * (0.95 + 0.05 * sin(_t * 1.7 + _seed))
		"flicker":
			var dip := 1.0
			if fmod(_t + _seed, 3.7) < 0.12:
				dip = 0.25
			elif fmod(_t * 7.0 + _seed, 11.0) < 0.06:
				dip = 0.55
			_mat.emission_energy_multiplier = _base * dip
		"buzz":
			var buzz := 0.85 + 0.15 * sin(_t * 47.0 + _seed)
			if fmod(_t + _seed, 5.3) < 0.05:
				buzz = 0.1
			_mat.emission_energy_multiplier = _base * buzz
		"broken":
			# Dark most of the time; now and then a dying strobe.
			var phase := fmod(_t + _seed, 6.0)
			var on := 0.06
			if phase > 3.2 and phase < 3.5:
				on = 1.0 if fmod(phase * 60.0, 2.0) < 1.0 else 0.1
			elif phase > 4.9:
				on = 0.5
			_mat.emission_energy_multiplier = _base * on
