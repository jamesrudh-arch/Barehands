extends Control

## THE MAIN MENU (rebuild step 1): PLAY, CONTINUE, SETTINGS, CREDITS
## over a dark skyline backdrop (the real 3D drifting street and the
## key-art title land at teardown step 13). Everything works: PLAY
## starts the game, CONTINUE states honestly that saves arrive with
## the ledger build (it is disabled, never silently dead), SETTINGS
## holds live controls, CREDITS lists every CC0 source.

const BUTTONS := [
	["PLAY", "play"],
	["CONTINUE", "continue"],
	["SETTINGS", "settings"],
	["CREDITS", "credits"],
]

var _panel: PanelContainer
var _panel_title := ""
var _continue: Button
var _has_save := false


func _ready() -> void:
	Game.set_state(Game.State.MENU)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.024, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var sky := Skyline.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var f := SystemFont.new()
	f.font_names = ["Arial Black", "Arial", "sans-serif"]
	# the small title mark, top-left, out of the button zone
	var mark := Label.new()
	mark.text = "LEVERAGE"
	mark.add_theme_font_override("font", f)
	mark.add_theme_font_size_override("font_size", 34)
	mark.add_theme_color_override("font_color", Color(0.95, 0.96, 0.99))
	mark.position = Vector2(48, 40)
	add_child(mark)
	var tag := Label.new()
	tag.text = "Everyone has leverage on you."
	tag.add_theme_font_override("font", f)
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", Color(0.55, 0.56, 0.68))
	tag.position = Vector2(50, 84)
	add_child(tag)
	# the buttons, lower-left (safe area), big touch targets
	var box := VBoxContainer.new()
	box.position = Vector2(48, size.y - 380)
	box.custom_minimum_size = Vector2(300, 300)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	for entry in BUTTONS:
		var b := Button.new()
		b.text = entry[0]
		b.name = entry[1].capitalize() + "Btn"
		b.custom_minimum_size = Vector2(280, 56)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_button.bind(entry[1]))
		box.add_child(b)
		if entry[1] == "continue":
			_continue = b
			var sg := get_node_or_null("/root/SaveGame")
			if sg:
				_has_save = sg.call("exists")
			b.disabled = not _has_save
	# the reason line under CONTINUE, always visible and honest
	var note := Label.new()
	note.name = "ContinueNote"
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.45, 0.47, 0.58))
	note.position = Vector2(50, size.y - 70)
	add_child(note)
	_refresh_continue_note(_has_save)
	# the studio line + build stamp at the bottom edge
	var prod := Label.new()
	prod.text = "A D'YOUNGS GAMES production"
	prod.add_theme_font_size_override("font_size", 13)
	prod.add_theme_color_override("font_color", Color(0.55, 0.56, 0.68))
	prod.position = Vector2(50, size.y - 44)
	add_child(prod)
	var stamp := Label.new()
	stamp.name = "StampLine"
	stamp.text = BuildStamp.line() if _stamp_ok() else ""
	stamp.add_theme_font_size_override("font_size", 12)
	stamp.add_theme_color_override("font_color", Color(0.4, 0.42, 0.52))
	stamp.position = Vector2(size.x - 360, size.y - 44)
	stamp.size = Vector2(340, 20)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(stamp)
	_build_panel()


func _stamp_ok() -> bool:
	var bs := get_node_or_null("/root/BuildStamp")
	return bs != null and bs.has_method("line")


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "MenuPanel"
	_panel.position = Vector2(size.x * 0.5 - 280, 90)
	_panel.custom_minimum_size = Vector2(560, 420)
	_panel.visible = false
	add_child(_panel)


## CONTINUE's honest line: what a save is worth right now.
func _refresh_continue_note(has_save: bool) -> void:
	var n := get_node_or_null("ContinueNote") as Label
	if n == null:
		return
	if has_save:
		var d: Dictionary = get_node("/root/SaveGame").call("load_data")
		var debt := float(d.get("world", {}).get("values", {}).get(
				"debt", 0.0)) if not d.is_empty() else 0.0
		n.text = "CONTINUE - the debt stands at $%d" % int(debt)
	else:
		n.text = "CONTINUE: no save yet - PLAY writes one at every landing"


func _on_button(which: String) -> void:
	match which:
		"play":
			Game.start_new_game()
		"continue":
			if _has_save:
				Game.continue_game()
		"settings":
			_open_settings()
		"credits":
			_open_credits()


func _open_settings() -> void:
	_show_panel("SETTINGS")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	_toggle(col, "Skip the intro", "skip_intro")
	_toggle(col, "Invert camera Y", "invert_look")
	_toggle(col, "Left-handed layout", "left_handed")
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(_close_panel)
	col.add_child(close)


func _open_credits() -> void:
	_show_panel("CREDITS")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	_credit(col, "D'YOUNGS GAMES", "LEVERAGE — Everyone has leverage on you.")
	_credit(col, "KayKit characters & animations (Kay Lousberg)",
			"CC0 1.0 — kaylousberg.com")
	_credit(col, "Universal Animation Library (Quaternius)",
			"CC0 1.0 — quaternius.com")
	_credit(col, "City, vehicle, furniture & audio kits (Kenney)",
			"CC0 1.0 — kenney.nl")
	_credit(col, "Godot Engine 4.7", "MIT — godotengine.org")
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(_close_panel)
	col.add_child(close)


func _credit(col: VBoxContainer, title: String, sub: String) -> void:
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color(0.91, 0.85, 0.66))
	col.add_child(t)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 14)
	s.add_theme_color_override("font_color", Color(0.62, 0.64, 0.75))
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(520, 0)
	col.add_child(s)


func _toggle(col: VBoxContainer, label: String, key: String) -> void:
	var cb := CheckButton.new()
	cb.text = label
	# Settings.value() answers null for a key nobody has set yet, and
	# bool(null) is a constructor error in Godot 4 - compare, never cast
	cb.button_pressed = Settings.value(key) == true
	cb.toggled.connect(func(on): Settings.set_value(key, on))
	col.add_child(cb)


func _show_panel(title: String) -> void:
	_close_panel()
	_panel_title = title
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	_panel.visible = true


func _close_panel() -> void:
	_panel.visible = false
	_panel_title = ""


func panel_title() -> String:
	return _panel_title


## The skyline backdrop (the same drawn silhouette family as the
## title card — one look everywhere).
class Skyline:
	extends Control

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var y := size.y
		var x := 0.0
		while x < size.x:
			var w := rng.randf_range(50, 130)
			var h := rng.randf_range(120, 320)
			draw_rect(Rect2(x, y - h, w, h),
					Color(0.028, 0.033, 0.08))
			for i in int(h / 48.0):
				for j in int(w / 32.0):
					if rng.randf() < 0.13:
						var wc := Color(1.0, 0.03, 0.5) \
								if rng.randf() < 0.5 \
								else Color(0.0, 0.94, 1.0)
						draw_rect(Rect2(x + 9 + j * 28,
								y - h + 14 + i * 44, 8, 12), wc)
			x += w + rng.randf_range(8, 30)
		draw_rect(Rect2(0, y - 340, size.x, 340),
				Color(0.5, 0.1, 0.4, 0.06))
