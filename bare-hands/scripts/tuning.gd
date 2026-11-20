extends Node
## Tuning - THE one table for every gameplay number (Batch 0, prompt 9D).
## Values live here and nowhere else; scripts read Tuning.v("key").
## user://tuning_overrides.json stores live changes from the debug TUNING
## PANEL so the owner can tweak on the phone and the numbers survive a
## restart. A bad or missing override falls back to the default and logs,
## never crashes.
##
## First pass (honest scope): the table below carries the balance defaults
## from the design prompt section 14 plus this repo's shipped systems.
## Wiring scripts to it is staged so no suite breaks mid-migration; each
## system that switches to Tuning.v() is listed in STATE.json.

const DEFAULTS := {
	# --- combat: damage and health (section 14) ---
	"player_hp": 100.0,
	"composure_max": 100.0,
	"composure_hit_drain": 18.0,  # a landed hit on the hero
	"composure_block_drain": 7.0,  # a blocked strike chips it
	"composure_regen_per_s": 12.0,  # calm regen
	"composure_regen_delay_s": 2.5,  # nothing has bitten the hero for this long
	"guard_break_seconds": 4.0,  # block is dead for this long
	"thug_hp": 40.0,
	"guard_hp": 70.0,
	"heavy_hp": 160.0,
	"gunman_hp": 50.0,
	"light_damage": 6.0,
	"heavy_damage": 16.0,
	"parry_posture_damage": 30.0,
	"posture_max": 100.0,
	# --- combat: timing (section 14; the repo's current feel) ---
	"hitstop_light_frames": 3.0,
	"hitstop_heavy_frames": 8.0,
	"input_buffer_ms": 350.0,  # shipped feel (the design guess was 200)
	"block_hold_ms": 250.0,  # hold-DODGE this long -> block (lower = easier)
	"autotarget_mult": 1.0,  # soft auto-target strength: reach multiplier
	"phone_ring_seconds": 8.0,  # the answer window while enemies swing
	"phone_demand_cost": 40.0,  # a demand call's ask
	"phone_ambient_s": 180.0,  # calm-time minutes between ambient rings
	"debt_start_family": 3500.0,  # first-pass split of the bible's 5000
	"debt_start_corp": 1500.0,  # the Corporation's slice at boot
	"rate_family": 0.03,  # Family interest per day (bible 14)
	"rate_corp": 0.08,  # Corporation interest per day
	"beat_real_seconds": 360.0,
	"overnight_heat_cool": 1.0,  # stars the night takes off (world sim)
	"trust_skip_drift": 2.0,  # magnitude: what a day unseen costs a Warm+ friend (the sign lives in trust.gd)
	"rumor_age_days": 2,  # days a street rumor stays in retelling  # real minutes a beat lasts if nothing spends it
	"s_rank_cut": 0.05,  # each banked S-rank cuts 5% of the balance
	"launder_cut": 0.20,  # the Club Owner's take (bible 4G)
	"pay_chip": 100,  # the Ledger screen's quick-pay chip
	"hangout_trust": 15.0,  # the bible's +15 per hangout (4D)
	"hangout_wide_trust": 8.0,  # first pass: a botched timing still counts, barely
	"hangout_sweep_s": 1.2,  # one sweep of the timing marker, seconds
	"posture_regen_per_s": 20.0,
	"posture_break_seconds": 2.8,  # the finisher window
	"attack_tokens_ring": 2.0,  # bible 4A: max concurrent attackers, 3-4 engaged
	"attack_tokens_crowd": 3.0,  # bible 4A: max concurrent attackers, 5+ engaged
	"parry_window_ms": 300.0,
	"dodge_window_ms": 120.0,
	"cancel_start_ms": 150.0,
	"cancel_end_ms": 350.0,
	"combo_chain_window_ms": 600.0,
	"attack_tokens": 2.0,
	"attack_tokens_gunfights": 3.0,
	# --- meters this repo already ships ---
	"super_gain_rate": 1.0,
	"super_parries_gain": 14.0,
	"super_counters_gain": 18.0,
	"style_rank_decay_per_s": 4.0,
	"launch_gravity_mult": 1.35,
	"launch_up_speed": 6.5,
	"launch_knock_speed": 2.5,
	# --- ledger and economy (section 14) ---
	"starting_debt": 5000.0,
	"interest_family_pct": 3.0,
	"interest_corp_pct": 8.0,
	"interest_crew_pct": 0.0,
	"missed_payments_default": 3.0,
	"death_debt": 800.0,
	"job_pay_min": 400.0,
	"job_pay_max": 1500.0,
	"s_rank_debt_cut_pct": 5.0,
	"launder_cut_pct": 20.0,
	# --- beats and trust (sections 3 and 4D) ---
	"beats_per_day": 3.0,
	"beat_cost_call": 1.0,
	"beat_cost_job": 1.0,
	"beat_cost_hangout": 1.0,
	"trust_start": 70.0,
	"trust_decay_per_beat": 6.0,
	"trust_hangout_gain": 15.0,
	"trust_setup_clean_gain": 10.0,
	"trust_setup_hurt_loss": 10.0,
	"trust_close_min": 60.0,
	"trust_drifting_min": 30.0,
	# --- city and crowd (section 13 budgets) ---
	"crowd_cap_hero": 25.0,
	"crowd_cap_floor": 15.0,
	"decal_cap": 150.0,
	"muscle_spawn_radius": 14.0,
}

const OVERRIDE_PATH := "user://tuning_overrides.json"

var _values: Dictionary = {}


func _ready() -> void:
	_load_overrides()


## The value for a key: the live override if present, else the default.
## An unknown key logs a warning (a typo in gameplay code) and returns the
## default 0.0 so the caller fails visibly, not silently.
func v(key: String) -> float:
	if _values.has(key):
		return float(_values[key])
	if DEFAULTS.has(key):
		return float(DEFAULTS[key])
	Log.warn("Tuning: unknown key '%s' (returning 0.0 - fix the key name)" % key)
	return 0.0


## Change a value live (from the TUNING PANEL) and persist it.
func set_v(key: String, value: float) -> void:
	if not DEFAULTS.has(key):
		Log.warn("Tuning: cannot set unknown key '%s'" % key)
		return
	_values[key] = value
	_save_overrides()


## Drop every override back to the defaults.
func reset_all() -> void:
	_values.clear()
	_save_overrides()


func is_overridden(key: String) -> bool:
	return _values.has(key)


func _load_overrides() -> void:
	if not FileAccess.file_exists(OVERRIDE_PATH):
		return
	var f := FileAccess.open(OVERRIDE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		for key in parsed:
			if DEFAULTS.has(key):
				_values[key] = float(parsed[key])
			else:
				Log.warn("Tuning: dropping unknown override '%s'" % key)
	else:
		Log.warn("Tuning: overrides file unreadable - using defaults")


func _save_overrides() -> void:
	var f := FileAccess.open(OVERRIDE_PATH, FileAccess.WRITE)
	if f == null:
		Log.warn("Tuning: cannot write overrides")
		return
	f.store_string(JSON.stringify(_values, "\t"))
	f.close()
