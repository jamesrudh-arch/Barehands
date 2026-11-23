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
	"weather_rain_chance": 0.6,  # rain frequent - the signature
	"weather_rain_stop": 0.35,  # it does eventually let up
	"rain_particles": 340.0,  # the column density (mobile-honest)
	"night_premium": 0.10,  # after MIDNIGHT everything costs more
	"launder_cap_drift": 0.35,  # each window the cap drifts +/-35%
	"taxi_fare": 25.0,  # the cab rides clean, any corner of the city
	"pawn_book_cost": 300.0,  # M4's third answer clears his book
	"outfit_price": 40.0,  # the stall's jackets
	"overnight_heat_cool": 1.0,  # stars the night takes off (world sim)
	"trust_skip_drift": 2.0,  # magnitude: what a day unseen costs a Warm+ friend (the sign lives in trust.gd)
	"rumor_age_days": 2,  # days a street rumor stays in retelling
	"job_overuse_at": 3,  # setups through one friend before their business eats it
	"kidnap_min_day": 3,  # the arc waits until the loop has teeth
	"kidnap_min_trust": 40,  # someone must matter enough to take
	"kidnap_days": 3,  # days before they stop feeding them
	"kidnap_ransom": 1200,  # the cold call's price
	"kidnap_payoff": 3000,  # the devil's offer
	"kidnap_enemy_floor": 1.5,  # permanent enemy: heat never cools below
	"fixer_at": 2.2,  # heat where the fixer texts (once a day)
	"fixer_base": 150,  # his opening price
	"fixer_per_heat": 100,  # ...plus this per point of heat
	"copy_at": 4.5,  # "the war": someone studied your tape
	"copy_cooldown_msec": 90000,  # the next tape-student waits
	"copy_hp_base": 6,  # the copy starts here ...
	"witness_mult": 1.5,  # 2+ wanderers watching: violence costs more
	"alley_mult": 0.6,  # nobody watching: it slides
	"hollow_wary_markup": 0.08,  # wary shelves are thin
	"launder_daily_drifting": 600,  # at trust "drifting" he moves this a day
	"launder_window_s": 300,  # the "day" stand-in until the cycle lands
	"noodles_price": 8,  # Old Dee's bowl (street price, dirty OK)
	"ammo_box_price": 25,  # Tony's box of twelve
	"ammo_box_rounds": 12,
	"economy_tick_s": 240,  # the overnight pressure's stand-in clock
	"debt_interest_tick": 0.005,  # ...what the debt grows per tick
	"escalate_hp_mult": 1.25,  # refused the Corporation: harder men
	"corp_ammo_mult": 0.5,  # accepted: their ammunition line, half
	# (launder_cut 0.20 already lives below - kept from the B6 economy pass)
	"palm_perfect_shift": 2,  # a clean palm bends the die this much
	"palm_good_shift": 1,  # a sloppy palm, half the bend
	"sleight_sweep_s": 1.4,  # the sleight window's sweep time
	"suspicion_ban": 4,  # the pit boss's count before the door shuts
	"suspicion_heat": 1.0,  # getting caught costs this much heat
	"watched_at_1": 400,  # winnings where the pit boss asks your name
	"watched_at_2": 1000,  # winnings where the room closes on you
	"watched_heat_1": 0.5,  # being asked about costs this
	"watched_heat_2": 1.5,  # being known costs more
	"watched_rep_cost": 10.0,  # the club doesn't like being beaten
	# (subtracted from market rep - tuning values stay >= 0)
	"dirty_spend_surcharge": 0.25,  # shops charge this on the dirty part
	"dirty_burn_min": 1000,  # a pocket this full gets noticed overnight
	"dirty_burn_heat": 0.3,  # ...and this hot by morning
	# the difficulty tiers (STREET is the 1.0 baseline above):
	"hard_hp": 1.5,  # sticks to drop a man
	"hard_telegraph": 0.85,  # faster tells - the read tightens
	"hard_composure": 1.25,  # hits drain more nerve
	"brutal_hp": 2.0,
	"brutal_telegraph": 0.7,
	"brutal_composure": 1.5,
	"hollow_turning_markup": 0.12,  # turning hostile: they're empty  # real minutes a beat lasts if nothing spends it
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
	# B30 THE DRUNKEN SLIP: the fraction of unguarded strikes that pass
	# through the drunk's lie and whiff clean (the miss costs the
	# attacker the parry stagger - the street calls it luck)
	"drunk_slip_chance": 0.22,
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
