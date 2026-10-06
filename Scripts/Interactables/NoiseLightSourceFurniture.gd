## The fireplace: both a light source and a noise source. LightSourceFurniture
## already covers the PointLight2D toggle; this composes the noise half of
## NoiseSourceFurniture.gd's behaviour on top of it. GDScript has no multiple
## inheritance, so the pattern is duplicated rather than shared - keep the
## two scripts in sync if noise-source behaviour changes.
class_name NoiseLightSourceFurniture
extends LightSourceFurniture

const SOUND_WAVES_SCENE := preload("res://Scenes/Effects/sound_waves.tscn")

@export var noise_audio: AudioStream
## Nudge/resize the ripple effect per furniture (centre is the node origin).
@export var wave_offset := Vector2.ZERO
@export var wave_size := Vector2(64, 64)

@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var _waves: SoundWaves


func _ready() -> void:
	add_to_group(&"noise_source")
	audio_player.stream = noise_audio
	audio_player.bus = &"SFX" # so the SFX volume slider actually reaches it
	# Before super._ready(), which calls activate()/deactivate() and needs _waves.
	_waves = SOUND_WAVES_SCENE.instantiate()
	_waves.size = wave_size
	_waves.position = wave_offset - wave_size * 0.5
	add_child(_waves)
	super._ready()

	GameEvents.day_started.connect(_on_day_started)
	if GameManager.is_day() and GameManager.current_personality == PersonalityProfile.Personality.OVERWHELMED:
		activate()


func activate() -> void:
	if audio_player.stream:
		audio_player.play()
	_waves.set_active(true)
	super()


func deactivate() -> void:
	audio_player.stop()
	_waves.set_active(false)
	super()


func _do_interact(actor: Node2D) -> Interactions.InteractionType:
	var result := super._do_interact(actor)
	if not is_active:
		GameEvents.noise_source_silenced.emit(self, _count_active_siblings())
	return result


func _on_day_started(_day: int, personality: int) -> void:
	if personality == PersonalityProfile.Personality.OVERWHELMED:
		activate()


func _count_active_siblings() -> int:
	var count := 0
	for n in get_tree().get_nodes_in_group(&"noise_source"):
		if n.is_active:
			count += 1
	return count
