class_name Fonts
extends RefCounted

## THE BUNDLED FONTS (S5.18): the type identity - Anton for the
## wordmarks (the LEVERAGE voice), Playfair Display for the
## studio serif, Barlow for every UI body. OFL-licensed, bundled
## so mobile renders the SAME face the desktop does (SystemFont
## fell back to Roboto on device - the identity died there).

static var _display: FontFile
static var _serif: FontFile
static var _body: FontFile
static var _medium: FontFile


static func display() -> FontFile:
	if _display == null:
		_display = load(
				"res://assets/fonts/Anton-Regular.ttf") as FontFile
	return _display


static func serif() -> FontFile:
	if _serif == null:
		_serif = load(
				"res://assets/fonts/PlayfairDisplay[wght].ttf") as FontFile
	return _serif


static func body() -> FontFile:
	if _body == null:
		_body = load(
				"res://assets/fonts/Barlow-Regular.ttf") as FontFile
	return _body


static func medium() -> FontFile:
	if _medium == null:
		_medium = load(
				"res://assets/fonts/Barlow-Medium.ttf") as FontFile
	return _medium
