extends CanvasLayer

## THE PAUSE MENU (rebuild step 8): PAUSE freezes the world through
## Game.pause_game (the tree pauses; this layer runs ALWAYS) and
## offers the real trio: RESUME, SETTINGS (the two live toggles),
## QUIT TO MENU. Every button does what it claims.

var _root: Control
var _settings: PanelContainer


func _ready() -> void:
	name = "PauseMenu"
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var col := VBoxContainer.new()
	col.name = "Menu"
	col.position = Vector2(60, 160)
	col.custom_minimum_size = Vector2(300, 240)
	col.add_theme_constant_override("separation", 14)
	_root.add_child(col)
	for entry in [["RESUME", _resume], ["SETTINGS", _settings_open],
			["QUIT TO MENU", _quit]]:
		var b := Button.new()
		b.text = entry[0]
		b.name = entry[0].replace(" ", "") + "Btn"
		b.custom_minimum_size = Vector2(280, 54)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(entry[1])
		col.add_child(b)
	_build_settings(col)


var _was_pause := false


func _process(_delta: float) -> void:
	# a state-based press EDGE: is_action_just_pressed() relies on
	# frame counters that synthetic mid-frame presses can miss; the
	# edge detector sees real and synthetic presses alike
	var p := Input.is_action_pressed("pause")
	if p and not _was_pause:
		if Game.state == Game.State.PLAY:
			_open()
		elif Game.state == Game.State.PAUSE:
			_resume()
	_was_pause = p
	if not _root.visible and Game.state != Game.State.PAUSE:
		return


func _open() -> void:
	Game.pause_game()
	_root.visible = true
	if _settings:
		_settings.visible = false


func _resume() -> void:
	Game.resume_game()
	_root.visible = false


func _settings_open() -> void:
	if _settings:
		_settings.visible = not _settings.visible


func _quit() -> void:
	# back to the main menu: unpause first, the menu is a scene swap
	Game.resume_game()
	_root.visible = false
	Game.go_menu()


func _build_settings(parent: VBoxContainer) -> void:
	_settings = PanelContainer.new()
	_settings.name = "SettingsPanel"
	_settings.visible = false
	parent.add_child(_settings)
	var col := VBoxContainer.new()
	_settings.add_child(col)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 18)
	col.add_child(title)
	for entry in [["Sound", "sound_on"], ["Haptics", "haptics_on"],
			["Invert look", "invert_look"]]:
		var cb := CheckButton.new()
		cb.text = entry[0]
		cb.button_pressed = Settings.value(entry[1]) == true
		cb.toggled.connect(func(on): Settings.set_value(entry[1], on))
		col.add_child(cb)
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(_settings_open)
	col.add_child(close)
