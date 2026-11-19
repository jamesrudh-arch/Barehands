class_name RetryOffer
extends CanvasLayer
## The instant arena retry (Batch 2, bible 2-min loop): when a strike lands
## on a guard-broken hero - the knockdown blow - this offer appears for
## ten seconds. Tap PUNCH to restart the fight fresh (the scene reloads,
## Composure/FightScore/SuperMeter reset; Wallet and Progression are meta
## and survive). Let it lapse and the hero just gets up and fights on.
## Story-fight Death = Debt arrives with the Ledger batch; this is the
## OPTIONAL-fight loop.

signal accepted

var _t := 0.0
var _lapsed := false


func _ready() -> void:
	layer = 95
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.02, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var title := Label.new()
	title.text = "KNOCKED DOWN"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.28))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "RETRY THE FIGHT?  -  TAP PUNCH"
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var timer := Label.new()
	timer.name = "Timer"
	timer.add_theme_font_size_override("font_size", 15)
	timer.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(timer)


func _process(delta: float) -> void:
	_t -= delta
	var timer := get_node_or_null("VBoxContainer/Timer") as Label
	if timer:
		timer.text = "%.1f s" % maxf(_t, 0.0)
	# the accept input: PUNCH while the offer is live
	if _t > 0.0 and InputBus.take_punch():
		accepted.emit()
	# the lapse is Death = Debt (bible 4G): no reload - the hero gets
	# up owing whoever patched them up. The Family runs the clinic.
	if _t <= 0.0 and not _lapsed:
		_lapsed = true
		Ledger.death_debt()
