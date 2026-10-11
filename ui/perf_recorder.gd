extends CanvasLayer
## Performance capture: press F9 to record 30 seconds of per-frame metrics.
##
## Each capture writes res://perf_logs/<map>_<date>_<time>.csv with one row per
## frame, and appends a one-line summary (average, 1% low, worst...) to
## res://perf_logs/summary.csv so runs can be compared. Exported builds can't
## write to res://, so they use user://perf_logs/ instead.

const KEY := KEY_F9
const DURATION := 30.0
const COLUMNS := ["time_s", "frame_ms", "fps", "process_ms", "physics_ms", "draw_calls", "primitives",
	"objects_drawn", "nodes", "physics_active_bodies", "video_mem_mb", "static_mem_mb"]

var _recording := false
var _start_usec := 0
var _last_usec := 0
var _rows: Array[PackedStringArray] = []
var _frame_ms: Array[float] = []
var _label: Label
var _message_until := 0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.offset_left = -520
	_label.offset_right = -14
	_label.offset_top = 10
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.hide()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY:
		if _recording:
			_finish()
		else:
			_begin()
		get_viewport().set_input_as_handled()


func _begin() -> void:
	_recording = true
	_rows.clear()
	_frame_ms.clear()
	_start_usec = Time.get_ticks_usec()
	# The first sample is taken on the next frame (the key press splits this one).
	_last_usec = 0
	_label.show()


func _process(_delta: float) -> void:
	if not _recording:
		if _label.visible and Time.get_ticks_msec() > _message_until:
			_label.hide()
		return
	var now := Time.get_ticks_usec()
	if _last_usec == 0:
		_last_usec = now
		_start_usec = now
		return
	var frame := (now - _last_usec) / 1000.0
	_last_usec = now
	var elapsed := (now - _start_usec) / 1000000.0
	if frame > 0.0:
		_frame_ms.append(frame)
		_rows.append(PackedStringArray([
			"%.4f" % elapsed, "%.3f" % frame, "%.1f" % (1000.0 / frame),
			"%.3f" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
			"%.3f" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0),
			str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))),
			str(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))),
			str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))),
			str(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))),
			str(int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))),
			"%.1f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
			"%.1f" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		]))
	_label.text = "● Recording performance  %d / %d s   (F9 to stop)" % [int(elapsed), int(DURATION)]
	if elapsed >= DURATION:
		_finish()


func _finish() -> void:
	_recording = false
	if _frame_ms.is_empty():
		_label.hide()
		return
	var folder := "res://perf_logs/" if OS.has_feature("editor") else "user://perf_logs/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	# Keep Godot from importing the logs (it turns CSVs into translations).
	if not FileAccess.file_exists(folder + ".gdignore"):
		FileAccess.open(folder + ".gdignore", FileAccess.WRITE).close()
	var scene := get_tree().current_scene
	var map := scene.name.to_snake_case() if scene != null else "unknown"
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := folder + "%s_%s.csv" % [map, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_show("Couldn't write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_csv_line(PackedStringArray(COLUMNS))
	for row in _rows:
		file.store_csv_line(row)
	file.close()
	var summary := _summary(map, stamp, path.get_file())
	_append_summary(folder + "summary.csv", summary)
	_show("Saved %s\nAvg %.1f FPS  |  1%% low %.1f FPS  |  Worst %.1f ms" % [path, summary["avg_fps"], summary["low1_fps"], summary["worst_ms"]])


func _summary(map: String, stamp: String, file_name: String) -> Dictionary:
	var ordered := _frame_ms.duplicate()
	ordered.sort()
	var total := 0.0
	for ms in ordered:
		total += ms
	var low_count := maxi(1, ceili(ordered.size() * 0.01))
	var slow := 0.0
	for index in range(ordered.size() - low_count, ordered.size()):
		slow += ordered[index]
	var over := 0
	for ms in ordered:
		if ms > 33.4:
			over += 1
	return {
		"date": stamp, "map": map, "preset": VideoSettings.current_preset(), "frames": ordered.size(),
		"seconds": total / 1000.0, "avg_fps": 1000.0 * ordered.size() / total, "avg_ms": total / ordered.size(),
		"median_ms": ordered[ordered.size() / 2], "p99_ms": ordered[mini(ordered.size() - 1, int(ordered.size() * 0.99))],
		"low1_fps": 1000.0 * low_count / slow, "worst_ms": ordered.back(), "frames_over_33ms": over,
		"render_scale": VideoSettings.get_value("render_scale"), "file": file_name,
	}


func _append_summary(path: String, summary: Dictionary) -> void:
	var exists := FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	if not exists:
		file.store_csv_line(PackedStringArray(summary.keys()))
	var values := PackedStringArray()
	for value in summary.values():
		values.append("%.2f" % value if value is float else str(value))
	file.store_csv_line(values)
	file.close()


func _show(text: String) -> void:
	_label.text = text
	_label.show()
	_message_until = Time.get_ticks_msec() + 6000
