extends Node
const CLS_Enemy := preload("res://scripts/enemy.gd")
## Friends in a fight (bible 4D tier effects), autoloaded as "FriendHelp".
## The knockdown blow is where friendship pays: a CLOSE friend (>=60)
## spends their once-per-fight save to answer it - the attacker takes
## the full gold stagger and the hero stays up. A DRIFTING friend
## (30-59) hesitates: they let the first knockdown of a fight happen
## and only answer the second. An ESTRANGED friend (<30) never answers
## (and never calls). "A fight" ends after FRIEND_CALM_S seconds with
## no enemy doing anything but standing around.

signal friend_saved(friend: String)

const FRIEND_CALM_S := 8.0

var _knockdowns := 0        # this fight's count
var _saved := false         # the once-per-fight save
var _calm_since := 0.0      # seconds since an enemy last meant harm
var _line: Label = null     # the floating answer line
var _line_t := 0.0

## The moves each friend answers with - one line of fiction each.
const ANSWERS := {
	"brother": "YOUR BROTHER CROSSES THE STREET - the tackle never lands",
	"mechanic": "THE MECHANIC KILLS THE STREETLIGHTS - the swing finds nothing",
	"club_owner": "THE CLUB OWNER'S BOUNCERS ARRIVE - the attacker reconsideres",
	"drunk": "THE DRUNK LOPS A BOTTLE - glass answers the blow",
}


func _ready() -> void:
	_calm_since = 0.0


func _process(delta: float) -> void:
	if fighting():
		_calm_since = 0.0
	else:
		_calm_since += delta
		if _calm_since >= FRIEND_CALM_S and (_knockdowns > 0 or _saved):
			_knockdowns = 0
			_saved = false
	# the floating line fades
	if _line:
		_line_t -= delta
		_line.modulate.a = clampf(_line_t, 0.0, 1.0)
		if _line_t <= 0.0:
			_line.queue_free()
			_line = null


## Any enemy doing anything hostile means the fight is live. Used here
## for the reset and by the hangouts for their street's-hot gate.
func fighting() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.state != CLS_Enemy.State.IDLE:
			return true
	return false


## The player just ate the knockdown blow: count it (the Drifting
## friend's hesitation reads off this).
func note_knockdown() -> void:
	_knockdowns += 1


## The save. False if it is not coming - then the knockdown plays out
## and the retry offer takes over.
func try_save(attacker: Node, at: Vector3) -> bool:
	if _saved or not is_instance_valid(attacker):
		return false
	var friend := _best_friend()
	if friend.is_empty():
		return false
	var tier := Trust.tier(friend)
	if tier == "estranged":
		return false
	if tier == "drifting" and _knockdowns < 1:
		return false  # they hesitate through the first one
	_saved = true
	# the answer: the attacker eats the gold stagger, full treatment
	attacker._posture_gain(999.0)
	Fx.haptic(30)
	Sound.play("metal_ring_1", -8.0, 0.9)
	_show_line(ANSWERS.get(friend, "A FRIEND ANSWERS THE BLOW"))
	Log.info("FriendHelp: %s saves the knockdown (tier %s)" % [friend, tier])
	friend_saved.emit(friend)
	return true


## The highest-Trust friend who has not stopped answering the phone.
func _best_friend() -> String:
	var best := ""
	var best_v := -1.0
	for id in Trust.FRIENDS:
		if Trust.tier(id) == "estranged":
			continue
		var v := Trust.value(id)
		if v > best_v:
			best_v = v
			best = id
	return best


## A short floating line where the offer shows - the street sees it.
func _show_line(text: String) -> void:
	if _line and is_instance_valid(_line):
		_line.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 93
	add_child(layer)
	_line = Label.new()
	_line.text = text
	_line.add_theme_font_size_override("font_size", 19)
	_line.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_line.position = Vector2(340, 180)
	_line.size = Vector2(600, 40)
	layer.add_child(_line)
	_line_t = 2.5


func reset_for_test() -> void:
	_knockdowns = 0
	_saved = false
	_calm_since = FRIEND_CALM_S  # not in a fight until one starts
	if _line and is_instance_valid(_line):
		_line.queue_free()
		_line = null
