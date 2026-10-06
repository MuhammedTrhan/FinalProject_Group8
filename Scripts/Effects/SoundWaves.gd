class_name SoundWaves
extends ColorRect
## Visual feedback for noise furniture: ripples travelling left and right of
## the source while it is active. Spawned by NoiseSourceFurniture /
## NoiseLightSourceFurniture; the look lives in Shaders/sound_waves.gdshader.
## The ShaderMaterial is local-to-scene, so each instance fades independently.

const FADE_TIME := 0.3

var _tween: Tween


func _ready() -> void:
	visible = false
	(material as ShaderMaterial).set_shader_parameter(&"phase", randf())


func set_active(on: bool) -> void:
	if _tween:
		_tween.kill()

	if on:
		visible = true

	_tween = create_tween()
	_tween.tween_property(material, "shader_parameter/intensity", 1.0 if on else 0.0, FADE_TIME)
	if not on:
		_tween.tween_callback(func() -> void: visible = false)
