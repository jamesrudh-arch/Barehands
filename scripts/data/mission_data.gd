class_name MissionData
extends Resource

## ONE MISSION (rebuild step 7): the spine of the game, as data.
## Stages complete on REAL conditions (the check id names what the
## player must do; missions.gd evaluates it against the live world -
## never a timer). Rewards and consequences land in WorldState.

@export var id := ""
@export var title := ""
@export var blurb := ""
## each stage: {objective: String, check: String, marker: Vector3,
##              area: String}  - marker/area say WHERE (the green
##              pulse); check says WHAT completes it.
@export var stages: Array = []
@export var reward_cash := 0
@export var reward_xp := 0.0
@export var next := ""   # the mission that chains from this one
