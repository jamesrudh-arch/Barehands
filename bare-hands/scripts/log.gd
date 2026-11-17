extends Node
## Tiny file logger. Autoloaded as "Log" (before Fx, see project.godot).
## Writes to user://barehands.log - one fresh file per launch, newest first at
## the top of the file so a phone user can read the boot info without scrolling.
## Where to find user:// on a phone:
##   - exported APK:  Android/data/<package>/files/barehands.log
##   - Xogot (iOS):   the Xogot app's Documents folder (On My iPhone > Xogot)

const FILE := "user://barehands.log"
const KEEP_LINES := 400  # ring buffer for the debug panel

var _recent: Array[String] = []
var _booted_at := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_booted_at = Time.get_datetime_string_from_system().replace("T", " ")
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f:
		f.store_line("=== Bare Hands 3D - session %s ===" % _booted_at)
		f.store_line("godot %s | %s | %s" % [Engine.get_version_info().string,
				OS.get_name(), OS.get_model_name() if OS.has_feature("mobile") else "desktop"])
		f.close()
	info("boot: %s" % ProjectSettings.get_setting("application/config/version", "dev"))


func info(msg: String) -> void:
	_write("INFO", msg)


func warn(msg: String) -> void:
	_write("WARN", msg)
	push_warning(msg)


func error(msg: String) -> void:
	_write("ERROR", msg)
	push_error(msg)


## Last ~KEEP_LINES log lines, for the debug panel.
func recent() -> Array[String]:
	return _recent.duplicate()


func _write(level: String, msg: String) -> void:
	var line := "[%s] %s" % [Time.get_time_string_from_system().replace(" ", ""), msg]
	print("(", level, ") ", line)
	_recent.append("%s %s" % [level, line])
	if _recent.size() > KEEP_LINES:
		_recent = _recent.slice(_recent.size() - KEEP_LINES)
	var f := FileAccess.open(FILE, FileAccess.READ_WRITE) if FileAccess.file_exists(FILE) else FileAccess.open(FILE, FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()
