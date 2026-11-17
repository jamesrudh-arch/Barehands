extends Node
## Tiny shared bus for touch input. Autoloaded as "InputBus" (see project.godot).
## The joystick writes `move`; the hero reads it. Keeps UI and gameplay decoupled.

var move := Vector2.ZERO  # x = strafe, y = forward/back, magnitude 0..1
