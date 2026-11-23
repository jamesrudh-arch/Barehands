class_name AttackData
extends Resource

## ONE ATTACK (rebuild step 5): everything a swing needs, as data.
## The five styles' move sets are tables of these; combat.gd reads
## them, the builder (scripts/player/build_style_data.gd) writes the
## .tres files, the MOVES screen and the tutorial will read the same
## rows - one truth per attack.

@export var id := ""
@export var clip: StringName = &""     # library clip, e.g. combat/Melee_1H_Attack_Chop
@export var damage := 5.0
@export var startup_s := 0.12          # windup before the hit window opens
@export var active_s := 0.10           # the hit window length
@export var recover_s := 0.22          # tail before control returns
@export var knockback := 2.0
@export var cancel_from_s := 0.18      # when the next input may cancel in
@export var reach := 1.7               # metres from the hero's centre
@export var arc := 1.25                # frontal cone, radians half-angle
@export var haptic := "light"
@export var audio_layers: PackedStringArray = ["punch_med_0"]
@export var meter_gain := 8.0          # Leverage Strike gain on hit
@export var posture_damage := 1.0      # posture bars it costs a blocking/braced target


func total_s() -> float:
	return startup_s + active_s + recover_s
