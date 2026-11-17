extends CanvasLayer
## Wires the on-screen JUMP and SPRINT buttons into InputBus. Both sit in the
## bottom-right corner where a right thumb lands in landscape. SPRINT is a
## hold button; JUMP fires the instant the touch goes down.

func _ready() -> void:
	$JumpBtn.button_down.connect(func() -> void: InputBus.queue_jump())
	$SprintBtn.button_down.connect(func() -> void: InputBus.sprint = true)
	$SprintBtn.button_up.connect(func() -> void: InputBus.sprint = false)
