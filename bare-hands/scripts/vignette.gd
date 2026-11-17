class_name VignetteLayer
extends CanvasLayer
## Fullscreen noir vignette (deep blue-black corners) over the 3D view but
## under the HUD. One canvas item, no cost worth mentioning.

const SHADER := preload("res://shaders/vignette.gdshader")

var _rect: ColorRect
var _flash: ColorRect
var _flash_a := 0.0


func _ready() -> void:
	add_to_group("vignette")
	layer = 5
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("strength", 0.42)
	_rect = ColorRect.new()
	_rect.material = mat
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.anchor_right = 1.0
	_flash.anchor_bottom = 1.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


## Brief colour punch on a perfect parry (called via Fx).
func flash(color: Color, dur := 0.35) -> void:
	_flash.color = Color(color.r, color.g, color.b, 0.32)
	_flash_a = dur


func _process(delta: float) -> void:
	if _flash_a > 0.0:
		_flash_a = maxf(_flash_a - delta, 0.0)
		var c := _flash.color
		c.a = 0.32 * (_flash_a / 0.35)
		_flash.color = c
