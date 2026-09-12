extends Node
## Player settings. Applies the volumes to the audio buses declared in
## default_bus_layout.tres and persists them, so they survive a restart.

const CONFIG_PATH := "user://settings.cfg"
const AUDIO_SECTION := "audio"

## Linear 0.0-1.0, which is what a slider binds to directly. Converted to dB
## on the way to the bus - audio is logarithmic, a raw linear value there
## would make the top half of the slider do almost nothing.
var music_volume: float = 1.0
var sfx_volume: float = 1.0


func _ready() -> void:
	load_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_to_bus(&"Music", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_to_bus(&"SFX", sfx_volume)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(AUDIO_SECTION, "music_volume", music_volume)
	config.set_value(AUDIO_SECTION, "sfx_volume", sfx_volume)
	config.save(CONFIG_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	var loaded := config.load(CONFIG_PATH) == OK # absent on a first run

	set_music_volume(config.get_value(AUDIO_SECTION, "music_volume", 1.0) if loaded else 1.0)
	set_sfx_volume(config.get_value(AUDIO_SECTION, "sfx_volume", 1.0) if loaded else 1.0)


# A slider dragged to 0 must be actual silence: linear_to_db(0) is -inf, which
# some platforms handle badly, so the bus is muted outright instead.
func _apply_to_bus(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("No '%s' audio bus - check default_bus_layout.tres" % bus_name)
		return

	AudioServer.set_bus_mute(idx, is_zero_approx(linear))
	if not is_zero_approx(linear):
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
