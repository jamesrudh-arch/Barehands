extends Node
## The jobs (bible 4F): five templates, ten core jobs, the three-beat
## spine of the 30-minute loop. A job is taken from the phone's board
## (that costs a Beat), scouted by walking its district (the marker
## sharpens from a block to a spot), then executed - delivery walks a
## package into a drop, rescue clears a guard and frees a body,
## coerced leans on a shopkeeper, hit marks a named target, turf holds
## the block through three waves. Clean Hands (no one dropped) pays
## the friend's trust; Wrecking pays the heat. The day is the
## deadline: sleep with a job live and it goes cold on them (-10).
## S-ranks in a job's fights cut the debt through the Ledger's own
## banked-rank system (bible 14) - nothing new to wire.

signal changed()

const TEMPLATES := {
	"delivery": {"name": "DELIVERY", "color": Color(0.55, 0.8, 0.6)},
	"rescue": {"name": "RESCUE", "color": Color(0.6, 0.75, 0.95)},
	"coerced": {"name": "COERCED", "color": Color(0.85, 0.7, 0.45)},
	"hit": {"name": "HIT", "color": Color(0.9, 0.45, 0.45)},
	"turf": {"name": "TURF", "color": Color(0.8, 0.55, 0.85)},
}

## The ten core jobs (bible 4F: two per template). friend = the setup:
## clean pays them +10 trust, a job gone cold or a wrecking finish
## burns the same. hard jobs pay for ambushes and waves.
const JOBS := [
	{"id": "courier_market", "title": "the market courier", "template": "delivery",
		"district": "market", "friend": "club_owner", "pay": 500,
		"hard": false,
		"blurb": "a case walks from the club to a corner of the market. nobody opens it."},
	{"id": "courier_foundry", "title": "the foundry run", "template": "delivery",
		"district": "foundry", "friend": "mechanic", "pay": 750,
		"hard": true,
		"blurb": "machine parts, no papers, no questions. the drop point bites."},
	{"id": "free_brothers_man", "title": "the brother's man", "template": "rescue",
		"district": "market", "friend": "brother", "pay": 900,
		"hard": false,
		"blurb": "the Family borrowed one of the brother's people. give them back."},
	{"id": "free_foundry_hand", "title": "the foundry hand", "template": "rescue",
		"district": "foundry", "friend": "mechanic", "pay": 1100,
		"hard": true,
		"blurb": "a debt-slaved hand on the foundry floor. two guards this time."},
	{"id": "lean_riverside", "title": "the riverside shark", "template": "coerced",
		"district": "riverside", "friend": "brother", "pay": 400,
		"hard": false,
		"blurb": "a stall by the water collects for the wrong people. explain the error."},
	{"id": "lean_fenced", "title": "the fenced goods", "template": "coerced",
		"district": "foundry", "friend": "club_owner", "pay": 600,
		"hard": false,
		"blurb": "stolen stock moves through a foundry stall. persuade the fence."},
	{"id": "cut_enforcer", "title": "the collector", "template": "hit",
		"district": "market", "friend": "brother", "pay": 1200,
		"hard": false,
		"blurb": "a collector who works children's shops. the Family won't miss him."},
	{"id": "cut_snitch", "title": "the snitch", "template": "hit",
		"district": "foundry", "friend": "mechanic", "pay": 1500,
		"hard": true,
		"blurb": "someone sold the garage's route to the Corporation. knife trained."},
	{"id": "hold_riverside", "title": "the riverside corner", "template": "turf",
		"district": "riverside", "friend": "drunk", "pay": 800,
		"hard": false,
		"blurb": "three waves want the corner by the noodle front. keep it."},
	{"id": "hold_market", "title": "the market floor", "template": "turf",
		"district": "market", "friend": "club_owner", "pay": 1000,
		"hard": true,
		"blurb": "the club's floor tax is due. collect it off their heads."},
]

const PHASES := ["AVAILABLE", "TAKEN", "RECON", "READY", "DONE", "LOST"]
const TOUCH := 1.6          # how close counts as "at the spot"
const WAVE_GAP := 1.2       # seconds between turf waves
const OVERUSE_DEFAULT := 3  # setups before the friend's business eats it

var offers: Array = []          # job ids on today's board (max 4)
var active: Dictionary = {}     # the live job: id, phase, downed, setups_at_take
var done: Array = []            # finished job ids (stays off the board)
var setups: Dictionary = {}     # friend id -> setups run through them

var _marker: MeshInstance3D
var _props: Array = []          # hostage/coerce bodies we spawned
var _spawned: Array = []        # enemies we spawned (tracked, cleaned)
var _wave := 0
var _wave_at := 0.0
var _poll := 0.0
var _hud: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	City.entered_district.connect(_on_district)
	_refresh_board(1)
	_build_hud()
	changed.emit()


func _process(delta: float) -> void:
	if active.is_empty() or active["phase"] != "READY":
		return
	_poll += delta
	if _poll < 0.4:
		return
	_poll = 0.0
	_exec_poll()


# --- the board ------------------------------------------------------------------


## Deterministic per day: four offers, drawn from the ten, never one
## already done or live.
func _refresh_board(day: int) -> void:
	offers = []
	var pool: Array = []
	for j in JOBS:
		if not done.has(j["id"]) and not active.get("id", "") == j["id"]:
			pool.append(j["id"])
	var start := (day * 7) % pool.size()
	for k in pool.size():
		if offers.size() >= mini(4, pool.size()):
			break
		var id: String = pool[(start + k) % pool.size()]
		offers.append(id)
	Log.info("Jobs: day %d board - %s" % [day, ", ".join(offers)])


func job_by_id(id: String) -> Dictionary:
	for j in JOBS:
		if j["id"] == id:
			return j
	return {}


func phase_of(id: String) -> String:
	if active.get("id", "") == id:
		return active["phase"]
	if offers.has(id):
		return "AVAILABLE"
	if done.has(id):
		return "DONE"
	return "CLOSED"


## Take it from the board. Costs a Beat (bible: every job spends one).
func take(id: String) -> bool:
	var live: bool = not active.is_empty() \
			and active.get("phase", "") not in ["DONE", "LOST"]
	if live or not offers.has(id):
		return false
	if not Ledger.spend_beat("job: %s" % id):
		_hint("NO BEATS LEFT - sleep, or take it tomorrow")
		return false
	var j := job_by_id(id)
	active = {"id": id, "phase": "RECON", "downed": 0, "day": Ledger.day}
	offers.erase(id)
	if City.district_now() == j["district"]:
		# you're already standing on the block - the recon is done
		active["phase"] = "READY"
		_spawn_execution(j)
		_hint("SPOT FOUND: %s - %s" % [j["title"], _exec_blurb(j)])
	Phone.push_text("fixer", "The fixer: \"%s. Walk %s first - eyes before hands.\""
			% [j["title"], _district_name(j["district"])])
	_hint("JOB TAKEN: %s - scout %s" % [j["title"], _district_name(j["district"])])
	Log.info("Jobs: taken %s (recon at %s)" % [id, j["district"]])
	changed.emit()
	return true


## Walk the district: recon done, the spot sharpens, execution spawns.
func _on_district(district: String, _mood: String) -> void:
	if active.is_empty() or active["phase"] != "RECON":
		return
	var j := job_by_id(active["id"])
	if j["district"] != district:
		return
	active["phase"] = "READY"
	_spawn_execution(j)
	_hint("SPOT FOUND: %s - %s" % [j["title"], _exec_blurb(j)])
	Phone.push_text("fixer", "The fixer: \"Found it. %s\"" % _exec_blurb(j))
	Log.info("Jobs: %s ready at %s" % [j["id"], district])
	changed.emit()


func _exec_blurb(j: Dictionary) -> String:
	match j["template"]:
		"delivery":
			return "carry the case to the light."
		"rescue":
			return "drop the guard, then the body is yours to walk."
		"coerced":
			return "lean on them at the light. words only, if the block is calm."
		"hit":
			return "the mark stands in the open. make it loud, leave fast."
		"turf":
			return "hold the light through three waves."
	return "finish it."


# --- execution -------------------------------------------------------------------


func _spot(j: Dictionary) -> Vector3:
	# a fixed open corner per district, nudged per job so two jobs in a
	# block never stack markers
	var base: Vector3 = {"riverside": Vector3(5.0, 0.02, 5.0),
		"market": Vector3(245.0, 0.02, 6.0),
		"foundry": Vector3(484.0, 0.02, -5.0)}[j["district"]]
	var idx := JOBS.find(j)
	return base + Vector3((idx % 3) * 1.5, 0.0, (idx % 2) * 1.5)


func _spawn_execution(j: Dictionary) -> void:
	_clear_entities()
	_marker = _build_marker(TEMPLATES[j["template"]]["color"], _spot(j))
	match j["template"]:
		"delivery", "coerced":
			pass  # the marker IS the target
		"rescue":
			_spawn_hostage(_spot(j))
			_spawn_enemy(j, 1)
			if j["hard"]:
				_spawn_enemy(j, 1)
		"hit":
			_spawn_enemy(j, 3 if j["hard"] else 1)
		"turf":
			_wave = 0
			_wave_at = 0.0
			_push_wave(j)


func _build_marker(color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = 5.0
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.65
	m.material_override = mat
	m.position = pos + Vector3(0, 2.5, 0)
	m.add_to_group("job_marker")
	get_tree().current_scene.add_child(m)
	return m


func _spawn_hostage(pos: Vector3) -> void:
	var b := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.5
	b.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.72, 0.62)
	b.material_override = mat
	b.position = pos + Vector3(0.9, 0.75, 0.0)
	b.add_to_group("job_prop")
	get_tree().current_scene.add_child(b)
	_props.append(b)


func _spawn_enemy(j: Dictionary, kind: int) -> void:
	var e := load("res://scenes/enemy.tscn").instantiate() as CharacterBody3D
	e.set("kind", kind)
	get_tree().current_scene.add_child(e)
	var s := _spot(j)
	e.global_position = Vector3(s.x + randf_range(-3.5, 3.5), 0.02,
			s.z + randf_range(-3.5, 3.5))
	_spawned.append(e)


func _push_wave(j: Dictionary) -> void:
	var count := 2 + (1 if _wave >= 2 else 0)
	for i in count:
		_spawn_enemy(j, 3 if (j["hard"] and _wave == 2 and i == 0) else 1)
	Log.info("Jobs: turf wave %d (%d up)" % [_wave + 1, count])


func _exec_poll() -> void:
	var j := job_by_id(active["id"])
	var p := _player()
	if p == null:
		return
	# count what dropped, drop what's gone
	var alive := 0
	for e in _spawned.duplicate():
		if not is_instance_valid(e):
			_spawned.erase(e)
		elif (e as Enemy).state == Enemy.State.DOWN:
			var counted: Array = active.get("_counted", [])
			if not counted.has(e):
				counted.append(e)
				active["_counted"] = counted
				active["downed"] += 1
				# a counted body is dragged off - it must never stand back
				# up into the next wave (enemy respawn is 2.6 s)
				(e as Node).queue_free()
		else:
			alive += 1
	var at_spot := p.global_position.distance_to(_spot(j)) < TOUCH
	match j["template"]:
		"delivery":
			if at_spot:
				if j["hard"] and not active.get("ambushed", false) \
						and _spawned.is_empty():
					# the drop bites: two step out - clear them, then it lands
					active["ambushed"] = true
					_spawn_enemy(j, 1)
					_spawn_enemy(j, 1)
					_hint("THE DROP BITES - clear it, then the case lands")
				elif not j["hard"] or active.get("ambushed", false):
					if alive == 0:
						_finish(j, true)
		"coerced":
			if at_spot:
				if Heat.heat >= 2.0 and _spawned.is_empty() \
						and not active.get("leaned", false):
					active["leaned"] = true
					_spawn_enemy(j, 1)
					_hint("THE BLOCK IS HOT - drop the guard, then lean")
				elif not active.get("leaned", false) or alive == 0:
					_finish(j, true)
		"rescue":
			var guard_up := false
			for e in _spawned:
				if is_instance_valid(e) and (e as Enemy).state != Enemy.State.DOWN:
					guard_up = true
			if not guard_up and at_spot:
				_finish(j, true)
		"hit":
			if alive == 0 and active["downed"] > 0:
				_finish(j, true)
		"turf":
			if alive == 0:
				_wave_at += 0.4  # poll cadence credit
				if _wave >= 2:
					_finish(j, true)
				elif _wave_at >= WAVE_GAP:
					_wave += 1
					_wave_at = 0.0
					_push_wave(j)


func _finish(j: Dictionary, ok: bool) -> void:
	var clean: bool = active.get("downed", 0) == 0
	var pay: int = j["pay"]
	if ok:
		Wallet.earn_dirty(pay, "job: %s" % j["id"])
		var friend: String = j["friend"]
		if clean:
			Trust.add(friend, 10.0, "clean setup: %s" % j["id"])  # bible 4D
			_hint("DONE CLEAN - $%d dirty, %s's trust up" % [pay, Trust.FRIENDS[friend]["name"]])
		else:
			Trust.add(friend, -10.0, "wrecking their setup: %s" % j["id"])
			Heat.add(1.0)
			_hint("WRECKING BALL - $%d dirty, the block heats up" % pay)
		setups[friend] = int(setups.get(friend, 0)) + 1
		if int(setups[friend]) >= int(Tuning.v("job_overuse_at")) \
				and not active.get("overused", false):
			active["overused"] = true  # per-job flag; the warning lands once per job
			_overuse(friend)
		done.append(j["id"])
		Phone.push_text("fixer", "The fixer: \"%s. Clean.\" Money's dirty, your hands aren't." % j["title"])
		Log.info("Jobs: DONE %s ($%d, %d dropped)" % [j["id"], pay, active["downed"]])
	else:
		Trust.add(j["friend"], -10.0, "job went cold: %s" % j["id"])
		Phone.push_text("fixer", "The fixer: \"%s went cold. That was %s's name on it.\""
				% [j["title"], Trust.FRIENDS[j["friend"]]["name"]])
		Log.warn("Jobs: LOST %s" % j["id"])
	_clear_entities()
	active = {"id": j["id"], "phase": "DONE" if ok else "LOST",
		"downed": active.get("downed", 0)}
	# the board keeps today's other offers; DONE ids never return
	changed.emit()


## Overuse (bible 4F): the friend's name gets heavy, their business
## eats it. The first warning is words; the setup keeps costing them.
func _overuse(friend: String) -> void:
	var home: String = Blocks.FRIEND_HOMES.get(friend, "riverside")
	var hx: float = Blocks.BLOCK_X.get(home, 0.0)
	City.note_damage_in(home, Vector3(hx + 2.0, 0.0, 4.0), "scorch")
	Phone.push_text(friend, "%s: \"people are asking why my door keeps ending up \
in your jobs. stop.\"" % Trust.FRIENDS[friend]["name"])
	Log.warn("Jobs: overuse - %s's business takes a mark (%s)" % [friend, home])


## The day rolls (world sim): a live job goes cold on the friend.
func on_day_rolled(new_day: int) -> void:
	if not active.is_empty() and active["phase"] in ["TAKEN", "RECON", "READY"]:
		var j := job_by_id(active["id"])
		_finish(j, false)
	_refresh_board(new_day)
	changed.emit()


# --- helpers ---------------------------------------------------------------------


func _player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _clear_entities() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
	for e in _spawned:
		if is_instance_valid(e):
			(e as Node).queue_free()
	_spawned = []
	for pr in _props:
		if is_instance_valid(pr):
			(pr as Node).queue_free()
	_props = []
	if not active.is_empty():
		active.erase("_counted")


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_buttons")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text, 3.2)


func _district_name(d: String) -> String:
	return d.replace("_", " ")


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_hud = Label.new()
	_hud.name = "Objective"
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.add_theme_color_override("font_color", Color(0.9, 0.8, 0.45))
	_hud.position = Vector2(14, 60)
	_hud.visible = false
	_hud.add_to_group("job_hud")
	layer.add_child(_hud)
	changed.connect(_refresh_hud)
	_refresh_hud()


func _refresh_hud() -> void:
	if active.is_empty():
		_hud.visible = false
		return
	var j := job_by_id(active["id"])
	if not j.is_empty() and active["phase"] in ["RECON", "READY"]:
		_hud.text = "JOB - %s (%s)" % [j["title"], active["phase"].to_lower()]
		_hud.visible = true
	else:
		_hud.visible = false


# --- persistence -------------------------------------------------------------------

func to_dict() -> Dictionary:
	var a := active.duplicate()
	a.erase("_counted")  # node refs never go into the save
	return {"offers": offers.duplicate(), "done": done.duplicate(),
		"setups": setups.duplicate(), "active": a}


func from_dict(d: Dictionary) -> void:
	offers = Array(d.get("offers", []))
	done = Array(d.get("done", []))
	setups = d.get("setups", {}).duplicate()
	active = d.get("active", {}).duplicate()
	active.erase("_counted")
	if active["phase"] == "READY":
		_spawn_execution(job_by_id(active["id"]))
	_refresh_hud()
	changed.emit()


func reset_for_test() -> void:
	_clear_entities()
	active = {}
	done = []
	setups = {}
	for f in Trust.FRIENDS:
		setups[f] = 0
	_refresh_board(Ledger.day)
	_refresh_hud()
	changed.emit()
