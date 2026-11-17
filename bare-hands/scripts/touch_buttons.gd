extends CanvasLayer
## Wires the on-screen buttons into InputBus and owns the hint label.
## JUMP fires the instant the touch goes down; SPRINT is a hold button.

var hint_shown := false
var _hint_fade := 0.0


func _ready() -> void:
	$JumpBtn.button_down.connect(func() -> void: InputBus.queue_jump())
	$SprintBtn.button_down.connect(func() -> void: InputBus.sprint = true)
	$SprintBtn.button_up.connect(func() -> void: InputBus.sprint = false)


## Called by the hero the first time the player stands near a climbable edge.
func show_hint(text: String, dur := 2.8) -> void:
	hint_shown = true
	var lbl := $HintLabel as Label
	lbl.text = text
	lbl.modulate.a = 1.0
	lbl.visible = true
	_hint_fade = dur


func _process(delta: float) -> void:
	if _hint_fade > 0.0:
		_hint_fade -= delta
		var lbl := $HintLabel as Label
		if _hint_fade <= 0.0:
			lbl.visible = false
		elif _hint_fade < 0.5:
			lbl.modulate.a = _hint_fade / 0.5
