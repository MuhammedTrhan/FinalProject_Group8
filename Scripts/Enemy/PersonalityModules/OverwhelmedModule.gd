class_name OverwhelmedModule
extends PersonalityModule
## Sways in place from the start of the day (Enemy puts him straight into
## State.SPECIAL because profile.starts_in_special is true) and panics if the
## house isn't quiet within PANIC_TIME seconds.

const PANIC_TIME := 45.0

var _panic_timer: float = 0.0
var _calmed := false


func _ready() -> void:
	GameEvents.noise_source_silenced.connect(_on_noise_source_silenced_signal)


func on_enter_special() -> void:
	_panic_timer = 0.0
	_calmed = false


func process_special(delta: float) -> void:
	if _calmed:
		return

	_panic_timer += delta
	if _panic_timer >= PANIC_TIME:
		enemy.escort_controller.register_catch(&"timeout")


func _on_noise_source_silenced_signal(_source: Node, remaining: int) -> void:
	on_noise_source_silenced(remaining)


func on_noise_source_silenced(remaining: int) -> void:
	if remaining == 0 and not _calmed:
		_calmed = true
		if enemy:
			enemy.drop_reward()
