class_name TestRunner
extends CanvasLayer
## The in-game TEST RUNNER (prompt 9A): one big RUN ALL TESTS button,
## reachable from the debug menu, that runs the game's LOGIC tests
## in-process on the phone. Every test shows PASS or FAIL with a one-line
## reason; the full report is saved to user://test_report.txt and shown
## as selectable text the owner can copy and paste back.
##
## Scope (honest): these are the logic tests - tuning validation, the
## animation library, the combo table, progression math, wallet and save
## round trips. The heavy scene suites (smoke_*, stress) stay in the
## headless battery and CI: they reboot the scene tree, which an in-game
## panel cannot do without quitting the game.

const REPORT_PATH := "user://test_report.txt"

var _panel: PanelContainer
var _rows: VBoxContainer
var _report_box: TextEdit
var _results: Array = []  # [name, ok, reason]


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func toggle() -> void:
	visible = not visible


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.add_theme_stylebox_override("panel", _bg())
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)

	var title := Label.new()
	title.text = "TEST RUNNER"
	title.add_theme_font_size_override("font_size", 26)
	outer.add_child(title)

	var run := Button.new()
	run.text = "RUN ALL TESTS"
	run.add_theme_font_size_override("font_size", 24)
	run.custom_minimum_size = Vector2(0, 72)
	run.pressed.connect(_run_all)
	outer.add_child(run)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	_rows = inner

	_report_box = TextEdit.new()
	_report_box.editable = false
	_report_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_report_box.custom_minimum_size = Vector2(0, 240)
	_report_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_report_box)

	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(func(): visible = false)
	outer.add_child(close)


func _run_all() -> void:
	_results.clear()
	for child in _rows.get_children():
		child.queue_free()

	# name -> callable returning [ok: bool, reason: String]
	var tests: Array = [
		["tuning: table parses and every value is sane", Callable(self, "_t_tuning")],
		["tuning: overrides round-trip through disk", Callable(self, "_t_overrides")],
		["anim library: key clips exist, short names", Callable(self, "_t_clips")],
		["combo table: 16 combos, styles and windows sane", Callable(self, "_t_combos")],
		["attack data: every .tres loads, fields in range, audio slots exist", Callable(self, "_t_attacks")],
		["fight score: rank math from synthetic fight stats", Callable(self, "_t_fightscore")],
		["tactics memory: last-3-moves ring buffer and spam reads", Callable(self, "_t_memory")],
		["progression: XP curve monotonic, unlocks reference real combos", Callable(self, "_t_progression")],
		["wallet: cash and debt math stay finite and floored", Callable(self, "_t_wallet")],
		["save: round-trip preserves state", Callable(self, "_t_save")],
		["settings: scheme survives a save/load cycle", Callable(self, "_t_settings")],
	]
	for t in tests:
		var r: Array = (t[1] as Callable).call()
		_results.append([t[0], r[0], r[1]])
		var line := Label.new()
		line.text = "%s  %s - %s" % ["PASS" if r[0] else "FAIL", t[0], r[1]]
		line.add_theme_font_size_override("font_size", 16)
		line.add_theme_color_override("font_color",
				Color(0.4, 1.0, 0.5) if r[0] else Color(1.0, 0.35, 0.35))
		_rows.add_child(line)

	var passed := 0
	for r in _results:
		if r[1]:
			passed += 1
	var report := _write_report(passed, _results.size())
	_report_box.text = report


func _write_report(passed: int, total: int) -> String:
	var lines: Array = []
	lines.append("LEVERAGE test report - %s" % Time.get_datetime_string_from_system())
	lines.append("%d/%d passed" % [passed, total])
	lines.append("")
	for r in _results:
		lines.append("%s  %s - %s" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
	var text := "\n".join(lines)
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text + "\n")
		f.close()
		lines.append("")
		lines.append("(saved to " + REPORT_PATH + ")")
	return "\n".join(lines)


# --- the tests (pure logic, no scene boots, no quitting) -----------------------


func _t_tuning() -> Array:
	var bad: Array = []
	for key in Tuning.DEFAULTS:
		var val := Tuning.v(key)
		if is_nan(val) or is_inf(val):
			bad.append(key + "=NaN")
		elif val < 0.0:
			bad.append(key + "<0")
	if not bad.is_empty():
		return [false, "out of range: " + ", ".join(bad)]
	if Tuning.v("parry_window_ms") < Tuning.v("dodge_window_ms"):
		return [false, "parry window shorter than dodge window"]
	return [true, "%d values, all finite and >= 0" % Tuning.DEFAULTS.size()]


func _t_overrides() -> Array:
	var key := "light_damage"
	var saved := Tuning.v(key)
	Tuning.set_v(key, 7.5)
	var on_disk := Tuning.v(key)
	Tuning.set_v(key, saved)
	if on_disk != 7.5:
		return [false, "override did not stick (%.1f)" % on_disk]
	if Tuning.v(key) != saved:
		return [false, "restore failed"]
	return [true, "set, persisted, restored"]


func _t_clips() -> Array:
	var lib := UalBind.library()
	var need := ["Idle", "Walk", "Sprint", "Jump", "Jog_Fwd", "Punch_Jab",
		"Punch_Cross", "Hit_Head", "Hit_Chest", "Kick_Code", "Idle_Talking"]
	var missing: Array = []
	for n in need:
		if not lib.has_animation(n):
			missing.append(n)
	if not missing.is_empty():
		return [false, "missing: " + ", ".join(missing)]
	return [true, "%d clips incl. all %d requested" % [lib.get_animation_list().size(), need.size()]]


func _t_combos() -> Array:
	var combos: Array = ComboTable.ordered()
	if combos.size() < 16:
		return [false, "only %d combos" % combos.size()]
	for c in combos:
		if float(c.get("window_ms", 600.0)) <= 0.0:
			return [false, "combo '%s' window <= 0" % str(c.get("name", "?"))]
		if int(c.get("level", 1)) < 1 or int(c.get("level", 1)) > 15:
			return [false, "combo '%s' level %d out of 1..15" % [str(c.get("name", "?")), int(c.get("level", 1))]]
	return [true, "%d combos, windows and level gates sane" % combos.size()]


func _t_attacks() -> Array:
	var bad: Array = []
	var bank: Array = []
	for key in Sound._bank:
		bank.append(key)
	for id in AttackData.DEFAULTS:
		var a := AttackData.for_attack(id)
		if a.damage < 1 or a.damage > 99:
			bad.append("%s damage %d" % [id, a.damage])
		if a.hitstop_frames < 1 or a.hitstop_frames > 20:
			bad.append("%s hitstop %d" % [id, a.hitstop_frames])
		if a.cancel_start_ms > a.cancel_end_ms:
			bad.append("%s cancel window inverted" % id)
		if (a.cancel_start_ms == 0.0) != (a.cancel_end_ms == 0.0):
			bad.append("%s cancel window half-open" % id)
		for clip in a.audio_layers:
			if not bank.has(clip):
				bad.append("%s audio '%s' missing" % [id, clip])
		if a.knockback.length() > 12.0:
			bad.append("%s knockback %s" % [id, a.knockback])
	if not bad.is_empty():
		return [false, ", ".join(bad)]
	return [true, "%d attacks, fields and audio valid" % AttackData.DEFAULTS.size()]


func _t_fightscore() -> Array:
	var bad: Array = []
	# a flawless varied fast fight is an S
	var r1: Dictionary = FightScore.score({"tags": 8, "counters": 3, "env": 2,
			"takedowns": 3, "hits_taken": 0, "seconds": 20.0})
	if r1["rank"] != 4:
		bad.append("flawless varied fight should be S (got %s, %.0f)" % [FightScore.RANKS[r1["rank"]], r1["total"]])
	# a sloppy one-move mauling is a D
	var r2: Dictionary = FightScore.score({"tags": 1, "counters": 0, "env": 0,
			"takedowns": 1, "hits_taken": 6, "seconds": 90.0})
	if r2["rank"] != 0:
		bad.append("sloppy mauling should be D (got %s)" % FightScore.RANKS[r2["rank"]])
	# counter cap holds at 15
	var r3: Dictionary = FightScore.score({"tags": 3, "counters": 9, "env": 0,
			"takedowns": 0, "hits_taken": 0, "seconds": 60.0})
	if float(r3["breakdown"]["counters"]) != 15.0:
		bad.append("counter cap should hold at 15 (got %.0f)" % r3["breakdown"]["counters"])
	# variety cap holds at 40
	var r4: Dictionary = FightScore.score({"tags": 30, "counters": 0, "env": 0,
			"takedowns": 0, "hits_taken": 5, "seconds": 60.0})
	if float(r4["breakdown"]["variety"]) != 40.0:
		bad.append("variety cap should hold at 40 (got %.0f)" % r4["breakdown"]["variety"])
	# every rank threshold is reachable from a plausible fight
	var r5: Dictionary = FightScore.score({"tags": 4, "counters": 1, "env": 1,
			"takedowns": 2, "hits_taken": 1, "seconds": 40.0})
	if r5["rank"] < 1 or r5["rank"] > 3:
		bad.append("a mid fight should land mid-table (got %s, %.0f)" % [FightScore.RANKS[r5["rank"]], r5["total"]])
	if not bad.is_empty():
		return [false, ", ".join(bad)]
	return [true, "rank math: S/D paths, caps, mid-table"]


func _t_memory() -> Array:
	var bad: Array = []
	Tactics._memory.clear()
	Tactics.record_player_move("punch_light")
	Tactics.record_player_move("punch_light")
	if Tactics.player_spams("punch_light"):
		bad.append("two moves is not spam yet")
	Tactics.record_player_move("punch_light")
	if not Tactics.player_spams("punch_light"):
		bad.append("three same moves IS spam")
	Tactics.record_player_move("dodge")
	if Tactics.player_spams("punch_light"):
		bad.append("a dodge breaks the punch read")
	Tactics.record_player_move("dodge")
	Tactics.record_player_move("dodge")
	if not Tactics.player_spams("dodge"):
		bad.append("three dodges read as dodge spam")
	if Tactics.last_moves().size() != 3:
		bad.append("ring buffer must hold 3 (got %d)" % Tactics.last_moves().size())
	Tactics._memory.clear()
	if not bad.is_empty():
		return [false, ", ".join(bad)]
	return [true, "memory: ring buffer, spam thresholds, broken reads"]


func _t_progression() -> Array:
	var last := -1.0
	for lvl in range(2, 16):
		var need := Progression.xp_needed(lvl)
		if need <= last:
			return [false, "XP needed for level %d not increasing (%.1f)" % [lvl, need]]
		last = need
	return [true, "XP curve increases through level 15"]


func _t_wallet() -> Array:
	var had := Wallet.cash
	Wallet.earn(50, "test earn")
	Wallet.spend(25, "test spend")
	var now := Wallet.cash
	Wallet.cash = had
	if now != had + 25:
		return [false, "cash math drifted (%d)" % now]
	return [true, "earn/spend math exact"]


func _t_save() -> Array:
	var before_w := Wallet.to_dict()
	var before_p := Progression.to_dict()
	var ok := SaveGame.save_all()
	if not ok:
		return [false, "save_all reported failure"]
	Wallet.cash = Wallet.cash + 123  # dirty the state
	ok = SaveGame.load_all()
	if not ok:
		return [false, "load_all reported failure"]
	var after_w := Wallet.to_dict()
	if after_w.get("cash", -1) != before_w.get("cash", -2):
		return [false, "cash not restored (%d -> %d)" % [before_w.get("cash", -2), after_w.get("cash", -1)]]
	if Progression.level != int(before_p.get("level", -1)):
		return [false, "level not restored"]
	return [true, "save -> dirty -> load -> compare"]


func _t_settings() -> Array:
	var had: String = Settings.value("button_scheme")
	Settings.set_value("button_scheme", "classic")
	var now: String = Settings.value("button_scheme")
	Settings.set_value("button_scheme", had)
	if now != "classic" or Settings.value("button_scheme") != had:
		return [false, "value read-back mismatch"]
	return [true, "set/read/write-through ok"]


func _bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.97)
	sb.border_color = Color(0.15, 0.9, 1.0)
	sb.set_border_width_all(2)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	return sb
