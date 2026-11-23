class_name StyleData
extends Resource

## ONE FIGHTING STYLE (rebuild step 5): its identity, stance and move
## table. The five styles must PLAY differently: distinct stance
## idles, distinct clips and timings behind the same X/Y/A/B
## (06_CONTROL_MAP) - the data IS the difference, the buttons stay
## constant.

@export var id := ""
@export var display := ""
@export var stance_clip: StringName = &""   # the style's idle pose clip
@export var blurb := ""                     # one line for MOVES/tutorial
@export var dodge_cost := 0.0               # styles move differently (later)
@export var punch_1: Resource = null        # AttackData
@export var punch_2: Resource = null
@export var punch_3: Resource = null
@export var heavy: Resource = null
@export var kick: Resource = null
@export var finisher: Resource = null       # posture-break ender
