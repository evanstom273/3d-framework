class_name GameSettings
extends RefCounted
## Player settings, saved to user://settings.cfg. Audio is split into buses so
## each kind of sound has its own volume; sound players pick a bus by name:
##   Impacts - hits, collisions, breaking
##   Tools   - tool motors, sprays, shots, prying
##   World   - switches and other things in the world

const PATH := "user://settings.cfg"
## Bus name, menu label, default volume (0..1).
const BUSES := [
	[&"Master", "Master", 0.6],
	[&"Impacts", "Impacts & breaking", 0.7],
	[&"Tools", "Tools", 0.6],
	[&"World", "Switches & world", 0.8],
]

static var _loaded := false
static var _volumes: Dictionary = {}


## Creates the buses and applies saved volumes. Safe to call more than once.
static func load_and_apply() -> void:
	_ensure_buses()
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	config.load(PATH)
	for bus in BUSES:
		_volumes[bus[0]] = clampf(float(config.get_value("audio", String(bus[0]), bus[2])), 0.0, 1.0)
		_apply(bus[0])


static func volume(bus: StringName) -> float:
	load_and_apply()
	return _volumes.get(bus, 1.0)


static func set_volume(bus: StringName, value: float) -> void:
	load_and_apply()
	_volumes[bus] = clampf(value, 0.0, 1.0)
	_apply(bus)


static func reset_audio() -> void:
	for bus in BUSES:
		set_volume(bus[0], bus[2])


static func save() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	for bus in BUSES:
		config.set_value("audio", String(bus[0]), _volumes.get(bus[0], bus[2]))
	VideoSettings.save(config)
	config.save(PATH)


static func _apply(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var value: float = _volumes.get(bus, 1.0)
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


static func _ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus[0]) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus[0])
		AudioServer.set_bus_send(index, &"Master")
