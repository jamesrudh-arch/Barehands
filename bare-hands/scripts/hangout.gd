class_name Hangout
extends CanvasLayer
## One hangout per friend (bible 4D): Fishing with the Brother,
## Basketball at the Mechanic's hoop, Darts in the Club Owner's back
## room, Karaoke in The Drunk's box - the SAME timing minigame
## skeleton wearing four skins (the bible says so, and it is true to
## the fiction: every one of these is one honest moment of timing).
## A marker sweeps a bar with a target band; PUNCH (or the bar) locks
## it. PERFECT/GOOD pay the bible's +15 Trust, WIDE pays +8 (first
## pass: the bible gives the +15, the miss haircut is our call). If
## the friend had an open promise from a call, the hangout redeems it.
## Costs one Beat, opened from the Ledger's Trust column; the street
## must be calm (no inviting anyone out while enemies hunt).

const THEMES := {
	"brother": {
		"game": "FISHING", "where": "the river at dawn",
		"hint": "the float dips - set the hook",
		"perfect": "A fat one. He says nothing, but he smiles the whole walk back.",
		"good": "A small one. \"Same river, same luck,\" he says. Good enough.",
		"wide": "The line snaps. He laughs until he has to sit down.",
	},
	"mechanic": {
		"game": "BASKETBALL", "where": "the garage hoop, floodlights on",
		"hint": "release at the top of the jump",
		"perfect": "Nothing but net. She calls it a fluke. She keeps the ball.",
		"good": "Off the rim, in. \"Fling, not shoot,\" she says. Fair.",
		"wide": "An air ball over the fence. The dog two yards over keeps it.",
	},
	"club_owner": {
		"game": "DARTS", "where": "the back room, one lamp on the board",
		"hint": "throw as the wobble crosses center",
		"perfect": "Inner bull. He raises his glass a single inch. High praise.",
		"good": "A solid twenty. \"You throw like a man with a plan,\" he says.",
		"wide": "Into the lamp. It swings shadows across the whole room.",
	},
	"drunk": {
		"game": "KARAOKE", "where": "the box at Lucky's, third song in",
		"hint": "catch the note as it crosses the line",
		"perfect": "You hold the note. He weeps openly. Best night in months.",
		"good": "Close enough for the room. He sings the harmony anyway.",
		"wide": "You crack on the high part. He joins the crack. Louder.",
	},
}

var friend := ""
var _theme: Dictionary = {}
var _marker: ColorRect = null
var _bar: Control = null
var _result: Label = null
var _done: Button = null
var _hint: Label = null
var _t := 0.0          # sweep position, 0..1
var _dir := 1.0
var _sweeps := 0
var _locked := false
var _slow_next := 0


## Everything that can block an invite, one answer. Returns "" when
## the hangout can start, otherwise the reason for the disabled chip.
static func blocked(friend_id: String) -> String:
	if Trust.tier(friend_id) == "estranged":
		return "STOPPED CALLING"
	if FriendHelp.fighting():
		return "STREET'S HOT"
	if Ledger.beats_left <= 0:
		return "NO BEATS"
	return ""


func open(friend_id: String) -> void:
	friend = friend_id
	_theme = THEMES[friend_id]
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	_build()


func _process(delta: float) -> void:
	# keep the world crawling while the hangout runs (the phone's idiom)
	var now := Time.get_ticks_msec()
	if now >= _slow_next:
		Fx.slow_mo(3.5, 0.25)
		_slow_next = now + 2000
	if _locked:
		return
	# the sweep: marker bounces across the bar
	_t += delta * _dir / float(Tuning.v("hangout_sweep_s"))
	if _t >= 1.0:
		_t = 1.0
		_dir = -1.0
		_sweeps += 1
	elif _t <= 0.0:
		_t = 0.0
		_dir = 1.0
		_sweeps += 1
	if _sweeps >= 3:
		lock()  # stood there waving - that is a WIDE
		return
	if _marker and _bar:
		_marker.position.x = _bar.position.x + _t * (_bar.size.x - _marker.size.x)
	# the lock input: PUNCH, same as the retry offer
	if InputBus.take_punch():
		lock()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var title := Label.new()
	title.text = "%s - %s" % [_theme["game"], Trust.FRIENDS[friend]["name"].to_upper()]
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Trust.FRIENDS[friend]["color"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var where := Label.new()
	where.text = _theme["where"]
	where.add_theme_font_size_override("font_size", 14)
	where.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(where)

	# the timing bar: a wide band with the target zone in the middle
	_bar = PanelContainer.new()
	_bar.custom_minimum_size = Vector2(640, 46)
	col.add_child(_bar)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.04, 0.05, 0.07, 0.95)
	bar_style.set_corner_radius_all(8)
	bar_style.border_color = Color(0.25, 0.28, 0.34)
	bar_style.set_border_width_all(1)
	_bar.add_theme_stylebox_override("panel", bar_style)

	var zone := ColorRect.new()
	zone.color = Color(0.2, 0.55, 0.35, 0.55)
	zone.set_anchors_preset(Control.PRESET_CENTER)
	zone.anchor_left = 0.5
	zone.anchor_right = 0.5
	zone.offset_left = -70
	zone.offset_right = 70
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(zone)

	var tick := ColorRect.new()
	tick.color = Color(1.0, 1.0, 1.0, 0.35)
	tick.set_anchors_preset(Control.PRESET_CENTER)
	tick.anchor_left = 0.5
	tick.anchor_right = 0.5
	tick.offset_left = -1
	tick.offset_right = 1
	tick.offset_top = -23
	tick.offset_bottom = 23
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(tick)

	_marker = ColorRect.new()
	_marker.color = Color(1.0, 0.85, 0.3)
	_marker.custom_minimum_size = Vector2(10, 46)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_marker)

	_hint = Label.new()
	_hint.text = _theme["hint"].to_upper() + "  -  TAP PUNCH"
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)

	# a fat touch target over the bar for fingers
	var tap := Button.new()
	tap.text = ""
	tap.flat = true
	tap.custom_minimum_size = Vector2(660, 70)
	tap.pressed.connect(lock)
	col.add_child(tap)

	_result = Label.new()
	_result.add_theme_font_size_override("font_size", 17)
	_result.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95))
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size = Vector2(620, 60)
	col.add_child(_result)

	_done = Button.new()
	_done.text = "WALK THEM HOME"
	_done.visible = false
	_done.pressed.connect(close)
	col.add_child(_done)


## Read the marker, pay the friend, redeem the promise.
func lock() -> void:
	if _locked:
		return
	_locked = true
	var offset := absf(_t - 0.5) * 2.0  # 0 dead center, 1 at the rail
	var grade := "WIDE"
	if offset < 0.22:
		grade = "PERFECT"
	elif offset < 0.55:
		grade = "GOOD"
	var trust_gain: float = Tuning.v("hangout_trust")
	if grade == "WIDE":
		trust_gain = Tuning.v("hangout_wide_trust")
	Trust.add(friend, trust_gain, "hangout: %s (%s)" % [_theme["game"], grade])
	Trust.note_interaction(friend)  # a hangout is seeing them
	var promised := Phone.redeem_promise(friend)
	var who: String = Trust.FRIENDS[friend]["name"]
	var text := "%s - %s" % [grade, _theme[grade.to_lower()]]
	if promised:
		text += "\n(a promise kept)"
	_result.text = text
	_result.add_theme_color_override("font_color",
			Color(0.5, 0.95, 0.6) if grade != "WIDE" else Color(0.9, 0.7, 0.4))
	_hint.text = "%s  +%d TRUST" % [who, int(trust_gain)]
	_done.visible = true
	Haptics.fire("buzz")
	Log.info("Hangout: %s with %s - %s (+%d trust)" % [_theme["game"], who, grade, int(trust_gain)])


func close() -> void:
	Fx.slow_mo(0.05, 1.0)  # let the world back up
	queue_free()
