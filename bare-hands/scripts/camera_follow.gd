extends Camera3D
## Smooth third-person follow camera. Sits behind and above the hero, looking at them.

@export var target_path: NodePath = ^"../Player"
@export var offset := Vector3(0.0, 6.5, 8.5)
@export var follow_speed := 4.0
@export var look_height := 1.4

@onready var _target: Node3D = get_node(target_path)


func _ready() -> void:
	global_position = _target.global_position + offset


func _physics_process(delta: float) -> void:
	var goal := _target.global_position + offset
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	look_at(_target.global_position + Vector3(0.0, look_height, 0.0))
