extends AudioStreamPlayer
## Loops a heartbeat while the antagonist is nearby, getting louder the
## closer he gets. The stream's own import settings already ping-pong loop
## it, so this only ever needs to start/stop playback and keep volume_db
## updated - never manually restart it.

## Beyond this distance, silent and stopped.
@export var max_distance: float = 160.0
## At/below this distance, full volume (max_volume_db).
@export var min_distance: float = 32.0
@export var min_volume_db: float = 0.0
@export var max_volume_db: float = 8.0
## Playback speed at max_distance/min_distance - races a little as he closes.
@export var min_pitch_scale: float = 1.0
@export var max_pitch_scale: float = 1.3

## Needed to read the position since AudioStreamPlayer does not have
## a global_position property.
var _player: Node2D
var _enemy: Node2D


func _ready() -> void:
	_player = get_parent()


func _process(_delta: float) -> void:
	# GameManager.spawn_player() runs before spawn_enemy(). So,
	# looking it up only once there would leave _enemy null forever. Keep
	# retrying here until it actually shows up.
	if _enemy == null or not is_instance_valid(_enemy):
		_enemy = get_tree().get_first_node_in_group(&"enemy")

	if not _is_enemy_trackable():
		stop()
		return

	var distance := _player.global_position.distance_to(_enemy.global_position)
	if distance > max_distance:
		stop()
		return

	var closeness := 1.0 - clampf((distance - min_distance) / (max_distance - min_distance), 0.0, 1.0)
	volume_db = lerpf(min_volume_db, max_volume_db, closeness)
	pitch_scale = lerpf(min_pitch_scale, max_pitch_scale, closeness)
	if not playing:
		play()


## Not while he's mid-teleport (floor crossing) or walking the player home
## during an escort - neither is the ordinary "he might catch you" tension
## this sound is meant to sell.
func _is_enemy_trackable() -> bool:
	return _enemy != null and is_instance_valid(_enemy) \
		and not _enemy.is_teleporting and not _enemy.escort_controller.is_escorting()
