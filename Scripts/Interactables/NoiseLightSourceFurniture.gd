## The fireplace: both a light source and a noise source. LightSourceFurniture
## already covers the PointLight2D toggle; this composes the noise half of
## NoiseSourceFurniture.gd's behaviour on top of it. GDScript has no multiple
## inheritance, so the pattern is duplicated rather than shared - keep the
## two scripts in sync if noise-source behaviour changes.
class_name NoiseLightSourceFurniture
extends LightSourceFurniture

@export var noise_audio: AudioStream

@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready() -> void:
	add_to_group(&"noise_source")
	audio_player.stream = noise_audio
	super._ready()

	GameEvents.day_started.connect(_on_day_started)
	if GameManager.is_day() and GameManager.current_personality == PersonalityProfile.Personality.OVERWHELMED:
		activate()


func activate() -> void:
	if audio_player.stream:
		audio_player.play()
	super()


func deactivate() -> void:
	audio_player.stop()
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
