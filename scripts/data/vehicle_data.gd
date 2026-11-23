class_name VehicleData
extends Resource

## ONE VEHICLE PROFILE (rebuild step 10): the arcade handling numbers
## as data. VehicleBody3D supplies the physics; these shape the feel
## per car - the sedan is calm, the taxi is punchier and looser.

@export var id := ""
@export var display := ""
@export var model := ""            # kit path under assets/kits
@export var body_size := Vector3(1.8, 0.9, 4.2)
@export var wheel_base := 2.6      # front-rear axle distance
@export var track := 1.45          # left-right wheel distance
@export var wheel_r := 0.34
@export var mass_kg := 640.0
@export var engine_force := 2100.0
@export var brake_force := 1800.0
@export var max_steer_deg := 34.0
@export var steer_speed := 5.0     # how fast the wheel turns
@export var handbrake_force := 2400.0
@export var downforce := 220.0     # keeps the arcade feel planted
@export var model_scale := 1.55    # the kit car to real proportions
@export var seat_offset := Vector3(-0.45, 0.55, 0.25)  # where the hero sits
