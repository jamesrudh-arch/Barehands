extends Node

## THE MUSIC LAYER (S5.19): the score finally PLAYS. The four
## tracks existed since the audio build and nothing ever loaded
## them - the game shipped silent behind its volume slider.
## This autoload owns two crossfading players on the Music bus:
##   - calm (menu + open street): the composed noir cue
##     (music_noir.wav - walking bass, brushes, piano stabs)
##   - combat: music_combat.wav, when live muscle is near
##   - endgame heartbeat: music_heartbeat.wav, once the story
##     turns (m6 answered, corp heat high)
## Fades are 1.2 s; the poll is cheap (1.5 s, distance-gated).

const FADE_S := 1.2

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _layer := ""
var _t := 0.0
var _streams := {}


func _ready() -> void:
	for n in ["music_noir", "music_combat", "music_heartbeat"]:
		var p := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.bus = "Music"
		add_child(p)
	set_layer("calm")


func set_layer(id: String) -> void:
	if id == _layer or not _streams.has(_track_for(id)):
		return
	_layer = id
	var incoming: AudioStream = _streams[_track_for(id)]
	# the free player takes the new layer; the old fades out
	var free_p := _b if _a.playing else _a
	var old_p := _a if free_p == _b else _b
	if free_p.stream != incoming or not free_p.playing:
		free_p.stream = incoming
		free_p.volume_db = -60.0
		free_p.play()
	# the user's volume rides the Music bus (the slider already
	# owns it); the layer itself fades in at -6 dB
	var tw := create_tween()
	tw.tween_property(free_p, "volume_db", -6.0, FADE_S)
	if old_p.playing:
		var tw2 := create_tween()
		tw2.tween_property(old_p, "volume_db", -60.0, FADE_S)
		tw2.finished.connect(old_p.stop)


func _track_for(id: String) -> String:
	match id:
		"combat":
			return "music_combat"
		"heartbeat":
			return "music_heartbeat"
		_:
			return "music_noir"


func _process(delta: float) -> void:
	_t += delta
	if _t < 1.5:
		return
	_t = 0.0
	# the combat read: live muscle inside 25 m of the hero
	var hero := get_tree().get_first_node_in_group("player") \
			as Node3D
	if hero == null or not is_instance_valid(hero):
		return
	var near := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and float(e.get("hp")) > 0.0 \
				and e.global_position.distance_to(
				hero.global_position) < 25.0:
			near += 1
	if near > 0:
		set_layer("combat")
	elif WorldState.flag("m6_declined") \
			or WorldState.flag("m6_accepted") \
			or WorldState.flag("corp_enemy"):
		set_layer("heartbeat")
	else:
		set_layer("calm")
