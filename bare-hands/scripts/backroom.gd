extends Node
## The back room (bible 4G: dirty money). THE VELVET ROOM's door in
## the club quarter opens on two services the club owner runs out of
## the back: LAUNDERING - he takes 20% to make street paper clean,
## and only for people he knows (trust "drifting" or better; at
## "drifting" he can only move $600 a day, at "close" the sky's the
## limit) - and STAKES: hi-lo dice at a lamp-lit table where the
## house takes your money one roll at a time. Sleight-of-hand is a
## choice: palm the die (the timing window) and the roll bends
## yours, but the pit boss counts hands as well as chips - four
## "somethings" and the room closes on you for the day, hot.
## Winning big gets you watched: $400 and he asks your name, $1000
## and the club doesn't like being beaten. And dirty money burns a
## hole: spending it where cash runs short costs 25% extra ("he
## charges for not asking"), and sleeping on $1000+ of it gets the
## street's attention.

const DOOR_SPOT := Vector3(231.0, 0.02, -8.4)  # the Velvet Room front
const STAKE_BETS := [50, 200, 500]
const BET_SIDES := ["high", "low"]

var laundered_today := 0       # toward the daily cap
var banned_day := -1           # the room closed on you until the next day
var suspicion := 0             # the pit boss's count (resets when you leave)
var session_won := 0           # this visit's winnings - being watched
var _watched_told := false     # the $400 text went out
var _closed_told := false      # the $1000 close happened

var _panel: Control
var _marker: MeshInstance3D
var _t := 0.0
var _bar_t := 0.0              # sleight sweep, 0..1
var _bar_live := false
var _bet := 200
var _side := "high"
var _result: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _open_if_at_door(p: CharacterBody3D) -> void:
	if banned_day >= Ledger.day:
		return
	if p.global_position.distance_to(DOOR_SPOT) < 1.8:
		open()


func _place_marker() -> void:
	_marker = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.22
	cyl.height = 3.0
	_marker.mesh = cyl
	var mat := StandardMaterial3D.new()
	var c := Color(0.85, 0.15, 0.3)
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.55
	_marker.material_override = mat
	_marker.position = DOOR_SPOT + Vector3(0, 1.5, 0)
	_marker.add_to_group("backroom_marker")
	get_tree().current_scene.add_child(_marker)


# --- the door -------------------------------------------------------------------------


## Inside: fresh eyes on you, the boss starts the count at zero.
func open() -> void:
	if _panel != null:
		return
	if banned_day >= Ledger.day:
		_hint("the back room is closed on you today")
		return
	suspicion = 0
	session_won = 0
	_watched_told = false
	_closed_told = false
	_build()
	Log.info("Backroom: in at the Velvet Room's back table")


func close() -> void:
	if _panel:
		_panel.queue_free()
	_panel = null
	_bar_live = false
	suspicion = 0


# --- services ------------------------------------------------------------------------


## Launder everything (bible 4G: 20% cut, through the club owner).
## Returns the clean take; 0 and a refusal line when he won't touch
## it. Trust "drifting" moves $600 a day; "close" moves it all.
func launder() -> int:
	if Trust.tier("club_owner") == "estranged" or Trust.value("club_owner") < 1.0:
		_text_from_owner("He looks at the money, then at you. \"Bring me \
something to trust first. The board in the back - you know where it is.\"")
		return 0
	var cut := float(Tuning.v("launder_cut"))
	var cap := launder_daily_cap()
	var amount := mini(Wallet.dirty, cap - laundered_today)
	if amount <= 0:
		_text_from_owner("\"That's all I can move today. \
Come back tomorrow - the books need to sleep.\"")
		return 0
	var take := int(floor(float(amount) * (1.0 - cut)))
	Wallet.dirty -= amount
	Wallet.cash += take
	Wallet._add("launder", "the Velvet Room", take)
	laundered_today += amount
	Phone.push_text("club_owner", "CLUB OWNER: \"$%d in, $%d out, \
20 for the house. Don't ask what happens to the rest.\"" % [amount, take])
	Log.info("Backroom: laundered $%d -> $%d clean (cut $%d)"
			% [amount, take, amount - take])
	return take


func launder_daily_cap() -> int:
	if Trust.tier("club_owner") == "close":
		return 1000000
	if Trust.tier("club_owner") == "drifting":
		return int(Tuning.v("launder_daily_drifting"))
	return 0


## One roll of hi-lo dice. The palm quality comes from the timing
## window: "perfect" bends the roll 2 your way, "good" bends it 1
## but the boss clocks the hand, "wide" fumbles in the lamplight,
## "none" plays it straight. Returns the result dictionary.
func resolve_stake(bet: int, side: String, palm: String) -> Dictionary:
	if not STAKE_BETS.has(bet) or not BET_SIDES.has(side):
		return {}
	if Wallet.total() < bet:
		return {"ok": false, "line": "the table doesn't take promises"}
	var shift := 0
	var sus_cost := 0
	match palm:
		"perfect":
			shift = int(Tuning.v("palm_perfect_shift"))
			sus_cost = 1  # even a clean palm counts, somewhere
		"good":
			shift = int(Tuning.v("palm_good_shift"))
			sus_cost = 2  # quick hands, quicker eyes
		"wide":
			sus_cost = 3  # you fumbled in the light
	var a := randi() % 6 + 1
	var b := randi() % 6 + 1
	var roll := a + b
	# the palm bends the die toward your call (capped at the bone)
	if side == "high":
		roll = mini(roll + shift, 12)
	else:
		roll = maxi(roll - shift, 2)
	suspicion += sus_cost
	var outcome := "push"
	if roll == 7:
		outcome = "push"
	elif (roll >= 8) == (side == "high"):
		outcome = "win"
	else:
		outcome = "lose"
	var line := ""
	if outcome == "win":
		Wallet.earn(bet, "the back table")
		session_won += bet
		line = "%d + %d = %d. Your number. Paid even." % [a, b, roll]
	elif outcome == "lose":
		Wallet.spend(bet, "the back table", "stake")
		line = "%d + %d = %d. The rake takes it." % [a, b, roll]
	else:
		line = "%d + %d = %d. A seven. No blood." % [a, b, roll]
	if palm == "perfect" and outcome == "win":
		line += " (the die sat a little too kindly)"
	_check_watched()
	_check_suspicion()
	return {"ok": true, "outcome": outcome, "roll": roll, "line": line}


## Winning big gets you watched (bible 4I hooks: heat and the word).
func _check_watched() -> void:
	if not _watched_told and session_won >= int(Tuning.v("watched_at_1")):
		_watched_told = true
		Heat.add(float(Tuning.v("watched_heat_1")))
		Phone.push_text("club_owner", "CLUB OWNER: \"The pit boss asked \
who you are. That's not a free question. Careful with the next one.\"")
	if not _closed_told and session_won >= int(Tuning.v("watched_at_2")):
		_closed_told = true
		banned_day = Ledger.day
		Heat.add(float(Tuning.v("watched_heat_2")))
		City.add_rep("market", -float(Tuning.v("watched_rep_cost")))
		Phone.push_text("club_owner", "CLUB OWNER: \"That's the room for \
today. The club doesn't like being beaten - and now they know your face. \
Out.\"")
		Log.warn("Backroom: the room closed on the big winner")
		_hint("the room closes on you - they know your face now")
		close()


## The pit boss's count: four somethings and you're done for the day.
func _check_suspicion() -> void:
	if suspicion >= int(Tuning.v("suspicion_ban")):
		banned_day = Ledger.day
		Heat.add(float(Tuning.v("suspicion_heat")))
		Phone.push_text("club_owner", "CLUB OWNER: \"The boss has been \
counting your hands since the second one. Out. Don't come back tonight.\"")
		Log.warn("Backroom: caught - the room is closed for the day")
		_hint("caught - the back room is closed to you today")
		close()


func on_day_rolled(_new_day: int) -> void:
	laundered_today = 0
	suspicion = 0
	session_won = 0
	_watched_told = false
	_closed_told = false


## Dirty money burns a hole (bible 4G): sleeping on a full pocket
## gets the street's attention. Returns the morning line, "" if quiet.
func dirty_pocket_line() -> String:
	if Wallet.dirty >= int(Tuning.v("dirty_burn_min")):
		Heat.add(float(Tuning.v("dirty_burn_heat")))
		return "you slept on a full pocket - the street saw the shape \
of it through the coat"
	return ""


# --- the panel ---------------------------------------------------------------------------


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = dim
	get_tree().current_scene.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(460, 0)
	dim.add_child(col)

	var title := Label.new()
	title.text = "THE VELVET ROOM - BACK ROOM"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.3))
	col.add_child(title)

	var body := Label.new()
	body.text = ("One lamp, one table, dice in a cup. Clean money and "
			+ "dirty money spend different here.\nCLEAN $%d   DIRTY $%d   (won today: $%d)"
			% [Wallet.cash, Wallet.dirty, session_won])
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(440, 0)
	col.add_child(body)

	_result = Label.new()
	_result.add_theme_font_size_override("font_size", 16)
	_result.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size = Vector2(440, 0)
	col.add_child(_result)

	# the launder service (trust-gated)
	var launder_btn := Button.new()
	var cap := launder_daily_cap()
	if Trust.value("club_owner") < 1.0 or cap == 0:
		launder_btn.text = "LAUNDER - he doesn't know you well enough \
(win his darts, first)"
		launder_btn.disabled = true
	elif Wallet.dirty <= 0:
		launder_btn.text = "LAUNDER - nothing dirty to move"
		launder_btn.disabled = true
	elif laundered_today >= cap:
		launder_btn.text = "LAUNDER - that's all he can move today"
		launder_btn.disabled = true
	else:
		launder_btn.text = "LAUNDER ALL - $%d dirty -> $%d clean (20%% cut)" % [
			mini(Wallet.dirty, cap - laundered_today),
			int(floor(mini(Wallet.dirty, cap - laundered_today)
					* (1.0 - float(Tuning.v("launder_cut")))))]
	launder_btn.pressed.connect(func() -> void:
		launder()
		_rebuild())
	col.add_child(launder_btn)

	# the stakes: bet, side, then the sleight window
	for bet in STAKE_BETS:
		var b := Button.new()
		b.text = "STAKE $%d - %s" % [bet, _side.to_upper()]
		b.disabled = Wallet.total() < bet
		b.pressed.connect(func() -> void:
			_bet = bet
			_roll_ui())
		col.add_child(b)

	var side_btn := Button.new()
	side_btn.text = "CALL %s (8+ high wins, 6- low wins, 7 pushes)" \
			% _side.to_upper()
	side_btn.pressed.connect(func() -> void:
		_side = "low" if _side == "high" else "high"
		_rebuild())
	col.add_child(side_btn)

	var leave := Button.new()
	leave.text = "LEAVE THE TABLE"
	leave.pressed.connect(close)
	col.add_child(leave)

	var hands := Label.new()
	hands.text = "the pit boss has counted %d of your hands" % suspicion
	hands.add_theme_font_size_override("font_size", 13)
	hands.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	col.add_child(hands)


func _rebuild() -> void:
	if _panel:
		close()
		_build()  # the panel redraws with fresh numbers


func _roll_ui() -> void:
	# the sleight window sweeps once across the rail; tap PALM inside
	# it to bend the die, or PLAY IT STRAIGHT
	if _panel:
		close()
	_build_sleight()


func _build_sleight() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = dim
	get_tree().current_scene.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(460, 0)
	dim.add_child(col)

	var title := Label.new()
	title.text = "THE CUP IS SHAKING - $%d on %s" % [_bet, _side]
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	col.add_child(title)

	# the rail and the sweeping tick
	var rail := ColorRect.new()
	rail.color = Color(0.25, 0.2, 0.15)
	rail.custom_minimum_size = Vector2(440, 22)
	col.add_child(rail)
	var perfect := ColorRect.new()
	perfect.color = Color(0.2, 0.7, 0.3, 0.8)
	perfect.position = Vector2(200, 3)
	perfect.size = Vector2(40, 16)
	rail.add_child(perfect)
	var good := ColorRect.new()
	good.color = Color(0.85, 0.6, 0.15, 0.6)
	good.position = Vector2(170, 3)
	good.size = Vector2(40, 16)
	rail.add_child(good)
	var tick := ColorRect.new()
	tick.name = "Tick"
	tick.color = Color(0.95, 0.95, 0.95)
	tick.position = Vector2(0, 0)
	tick.size = Vector2(4, 22)
	rail.add_child(tick)

	var palm := Button.new()
	palm.text = "PALM THE DIE (risky - the boss counts hands)"
	palm.pressed.connect(func() -> void:
		_resolve_with_palm())
	col.add_child(palm)

	var straight := Button.new()
	straight.text = "PLAY IT STRAIGHT"
	straight.pressed.connect(func() -> void:
		var r := resolve_stake(_bet, _side, "none")
		if _panel:
			_show_result(r))
	col.add_child(straight)

	_bar_t = 0.0
	_bar_live = true


func _process_bar(delta: float) -> void:
	if not _bar_live:
		return
	_bar_t += delta / float(Tuning.v("sleight_sweep_s"))
	if _bar_t > 1.0:
		_bar_t = 1.0
		_bar_live = false
	if _panel:
		var tick := _panel.find_child("Tick", true, false)
		if tick is ColorRect:
			(tick as ColorRect).position.x = 436.0 * _bar_t


func _resolve_with_palm() -> void:
	# the dead-center of the rail is the perfect palm; the edges fumble
	var offset := absf(_bar_t - 0.5) * 2.0
	var quality := "perfect"
	if offset > 0.55:
		quality = "wide"
	elif offset > 0.32:
		quality = "good"
	var r := resolve_stake(_bet, _side, quality)
	if _panel:
		_show_result(r)


func _show_result(r: Dictionary) -> void:
	if _panel:
		close()
	_build()
	if _result and not r.is_empty():
		_result.text = r.get("line", "")


func _text_from_owner(text: String) -> void:
	Phone.push_text("club_owner", "CLUB OWNER: " + text)


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_buttons")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text, 3.4)


func _process(delta: float) -> void:
	_t += delta
	_process_bar(delta)
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p == null:
		return
	if _panel != null:
		# the table is not a cage: walk six meters and you've left it
		if p.global_position.distance_to(DOOR_SPOT) > 6.0:
			close()
		return
	if City.district_at(p.global_position) == "market" and _marker == null:
		_place_marker()
	_open_if_at_door(p)


# --- persistence ---------------------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"laundered_today": laundered_today, "banned_day": banned_day}


func from_dict(d: Dictionary) -> void:
	laundered_today = int(d.get("laundered_today", 0))
	banned_day = int(d.get("banned_day", -1))


func reset_for_test() -> void:
	laundered_today = 0
	banned_day = -1
	suspicion = 0
	session_won = 0
	_watched_told = false
	_closed_told = false
	if _panel:
		close()
	if _marker and is_instance_valid(_marker):
		(_marker as Node).queue_free()
	_marker = null
