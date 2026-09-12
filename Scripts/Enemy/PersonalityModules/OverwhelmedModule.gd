class_name OverwhelmedModule
extends PersonalityModule
## Sways in place from the start of the day (Enemy puts him straight into
## State.SPECIAL because profile.starts_in_special is true), sitting and
## rocking left/right, and panics if the house isn't quiet within PANIC_TIME
## seconds - reacting for real (a chase, not an instant catch).

const PANIC_TIME := 45.0

## Rocking motion while seated - a plain Sprite2D rotation, not a second
## animation track (the AnimationPlayer never touches rotation).
const ROCK_PERIOD := 2.2 # seconds per full left-right-left cycle
const ROCK_AMPLITUDE_DEG := 8.0

var _panic_timer: float = 0.0
var _rock_time: float = 0.0
var _calmed := false


func _ready() -> void:
	GameEvents.noise_source_silenced.connect(_on_noise_source_silenced_signal)


func on_enter_special() -> void:
	_panic_timer = 0.0
	_rock_time = 0.0
	_calmed = false
	if enemy:
		enemy.sprite.rotation = 0.0


func process_special(delta: float) -> void:
	if _calmed:
		return

	_rock_time += delta
	if enemy:
		enemy.sprite.rotation = deg_to_rad(ROCK_AMPLITUDE_DEG) * sin(_rock_time * TAU / ROCK_PERIOD)

	_panic_timer += delta
	if _panic_timer >= PANIC_TIME:
		# Chase instead of an instant catch - gives the player a chance to escape
		# (she keeps her life, but doesn't get the item this cycle). _process_chase()
		# takes it from here exactly like any other personality's chase.
		var player := enemy.perception.get_player()
		var target := player.global_position if player and is_instance_valid(player) else enemy.global_position
		enemy.sprite.rotation = 0.0
		enemy.enter_chase(target)


func special_pose_animation() -> StringName:
	return &"sit_special"


func get_chase_progress() -> float:
	if _calmed:
		# He's back on patrol and can still notice the player after calming down.
		return enemy.perception.get_dwell_progress() if enemy else 0.0
	return clampf(_panic_timer / PANIC_TIME, 0.0, 1.0)


func _on_noise_source_silenced_signal(_source: Node, remaining: int) -> void:
	on_noise_source_silenced(remaining)


func on_noise_source_silenced(remaining: int) -> void:
	if remaining == 0 and not _calmed:
		_calmed = true
		if enemy:
			enemy.sprite.rotation = 0.0
			enemy.drop_reward()
			enemy.enter_patrol()
