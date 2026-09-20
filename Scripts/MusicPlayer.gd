extends AudioStreamPlayer
## Background music for the whole game. Autoloaded rather than placed in a
## scene, so it survives the change from the menu into the house instead of
## cutting off when Play is pressed.
##
## Ducks whenever the house is frozen - the pause menu, the dossier, the
## inventory - so a menu reads as a step back out of the game.

@export var playing_db: float = -18.0
@export var ducked_db: float = -24.0
@export var fade_time: float = 0.4

var _was_paused := false
var _tween: Tween


func _ready() -> void:
	volume_db = playing_db


func _process(_delta: float) -> void:
	var now := get_tree().paused
	if now == _was_paused:
		return

	_was_paused = now
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "volume_db", ducked_db if now else playing_db, fade_time)
