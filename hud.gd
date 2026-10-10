extends CanvasLayer
## Crosshair, interaction prompt layout, and frame performance display.

const FRAME_WINDOW_USEC: int = 10000000

var _fps_last_usec: int = 0
var _fps_window_frames: int = 0
var _fps_window_elapsed: float = 0.0
var _frame_end_usec: Array[int] = []
var _frame_times_ms: Array[float] = []

func _ready() -> void:
	$InteractionPrompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_resize)
	_resize()

func _process(_delta: float) -> void:
	# Measure real frame intervals so stalls and time scaling cannot hide low FPS.
	var now := Time.get_ticks_usec()
	if _fps_last_usec == 0:
		_fps_last_usec = now
		return
	var seconds := float(now - _fps_last_usec) / 1000000.0
	_fps_last_usec = now
	if seconds <= 0.0:
		return
	_frame_end_usec.append(now)
	_frame_times_ms.append(seconds * 1000.0)
	_fps_window_frames += 1
	_fps_window_elapsed += seconds
	# Keep the text readable without rebuilding it every frame.
	if _fps_window_elapsed >= 0.25:
		_update_performance_display(now, seconds * 1000.0)
		_fps_window_frames = 0
		_fps_window_elapsed = 0.0

func _update_performance_display(now: int, current_ms: float) -> void:
	# Expire by wall-clock age, including frames that ended after a loading stall.
	var expired := 0
	while expired < _frame_end_usec.size() and _frame_end_usec[expired] <= now - FRAME_WINDOW_USEC:
		expired += 1
	if expired > 0:
		_frame_end_usec = _frame_end_usec.slice(expired)
		_frame_times_ms = _frame_times_ms.slice(expired)
	var ordered := _frame_times_ms.duplicate()
	ordered.sort()
	var total_ms := 0.0
	for frame_ms in ordered:
		total_ms += frame_ms
	var average_ms := total_ms / ordered.size()
	var worst_ms: float = ordered.back()
	# 1% low = FPS corresponding to the mean duration of the slowest 1% of frames.
	var low_count := maxi(1, ceili(ordered.size() * 0.01))
	var slow_ms := 0.0
	for index in range(ordered.size() - low_count, ordered.size()):
		slow_ms += ordered[index]
	$FPSCounter.text = "FPS: %.0f  |  Frame: %.2f ms\n10s Avg: %.2f ms  |  Worst: %.2f ms\n1%% Low: %.1f FPS  |  Min: %.1f FPS" % [
		_fps_window_frames / _fps_window_elapsed, current_ms, average_ms, worst_ms,
		1000.0 * low_count / slow_ms, 1000.0 / worst_ms]

func _resize() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := maxf(0.1, minf(viewport_size.x / 1280.0, viewport_size.y / 720.0))
	var prompt: Label = $InteractionPrompt
	prompt.offset_left = -220.0 * factor
	prompt.offset_right = 220.0 * factor
	prompt.offset_top = 28.0 * factor
	prompt.offset_bottom = 74.0 * factor
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", maxi(10, roundi(13.0 * factor)))
	$Crosshair.add_theme_font_size_override("font_size", maxi(10, roundi(20.0 * factor)))
	var charge: ProgressBar = $ChargeBar
	charge.offset_left = -45.0 * factor
	charge.offset_right = 45.0 * factor
	charge.offset_top = 14.0 * factor
	charge.offset_bottom = 14.0 * factor + maxf(3.0, 5.0 * factor)
	$FPSCounter.position = Vector2(12.0, 8.0) * factor
	$FPSCounter.add_theme_font_size_override("font_size", maxi(10, roundi(13.0 * factor)))
