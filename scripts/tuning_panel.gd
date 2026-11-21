extends CanvasLayer

## The debug TUNING PANEL (prompt 9D): live sliders over Tuning's table,
## opened from the debug menu. Sliders change values in memory AND persist
## them to user://tuning_overrides.json immediately, so tweaks made on the
## phone survive a restart. A RESET button drops every override.

const KEYS_SHOWN := [
	"light_damage", "heavy_damage", "player_hp", "posture_max",
	"hitstop_light_frames", "hitstop_heavy_frames",
	"input_buffer_ms", "parry_window_ms", "dodge_window_ms",
	"cancel_start_ms", "cancel_end_ms", "combo_chain_window_ms",
	"launch_gravity_mult", "launch_up_speed",
	"super_parries_gain", "super_counters_gain", "style_rank_decay_per_s",
	"starting_debt", "death_debt", "job_pay_min", "job_pay_max",
	"trust_start", "trust_decay_per_beat",
]

var _panel: PanelContainer
var _sliders: Dictionary = {}  # key -> HSlider


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.add_theme_stylebox_override("panel", _bg())
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)

	var title := Label.new()
	title.text = "TUNING (live - changes save instantly)"
	title.add_theme_font_size_override("font_size", 22)
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	outer.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

	for key in KEYS_SHOWN:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var name_l := Label.new()
		name_l.text = key
		name_l.custom_minimum_size = Vector2(220, 0)
		name_l.add_theme_font_size_override("font_size", 15)
		row.add_child(name_l)
		var slider := HSlider.new()
		var lo := _lo(key)
		slider.min_value = lo
		slider.max_value = _hi(key)
		slider.step = _step(key)
		slider.custom_minimum_size = Vector2(240, 32)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(slider)
		_sliders[key] = slider
		var val_l := Label.new()
		val_l.custom_minimum_size = Vector2(70, 0)
		val_l.add_theme_font_size_override("font_size", 15)
		val_l.name = "Val"
		row.add_child(val_l)
		slider.value_changed.connect(func(_v: float):
			Tuning.set_v(key, _v)
			val_l.text = "%.1f" % _v)

	var buttons := HBoxContainer.new()
	outer.add_child(buttons)
	var reset := Button.new()
	reset.text = "RESET ALL TO DEFAULTS"
	reset.pressed.connect(func():
		Tuning.reset_all()
		_refresh())
	buttons.add_child(reset)
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(func(): visible = false)
	buttons.add_child(close)


func _refresh() -> void:
	for key in _sliders:
		var slider: HSlider = _sliders[key]
		slider.set_value_no_signal(Tuning.v(key))
		var row := slider.get_parent()
		(row.get_node("Val") as Label).text = "%.1f" % Tuning.v(key)


func _bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.96)
	sb.border_color = Color(0.15, 0.9, 1.0)
	sb.set_border_width_all(2)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	return sb


## Slider ranges: gameplay-safe brackets per key kind so a wild drag cannot
## freeze the phone (no 100000-frame hitstops, no negative windows).
func _lo(key: String) -> float:
	if key.ends_with("_ms"):
		return 0.0
	if "damage" in key or "hp" in key or "gain" in key or "pay" in key \
			or "debt" in key or "trust" in key:
		return 0.0
	return 0.0


func _hi(key: String) -> float:
	if key.ends_with("_ms"):
		return 1000.0
	if "damage" in key:
		return 60.0
	if "hp" in key or "posture" in key or "debt" in key:
		return 300.0
	if "pay" in key or "trust" in key or "gain" in key:
		return 150.0
	if "frames" in key:
		return 20.0
	return 20.0


func _step(key: String) -> float:
	if key.ends_with("_frames") or "tokens" in key:
		return 1.0
	return 1.0
