extends AudioStreamPlayer2D
## Positional footsteps for the enemy, so she can hear which way he is coming
## from before she can see him.
##
## Driven by the parent's velocity rather than by animation tracks, so it needs
## no change to his animations. The clip is imported with loop = false, so it
## is restarted whenever it runs out and he is still walking.

## His velocity never settles at exactly zero while navigating, so anything
## under this counts as standing still.
const MOVING_SPEED := 8.0

@onready var body: CharacterBody2D = get_parent()


func _ready() -> void:
	finished.connect(_on_finished)


func _physics_process(_delta: float) -> void:
	if _is_walking():
		if not playing:
			play()
	elif playing:
		stop()


func _on_finished() -> void:
	if _is_walking():
		play()


func _is_walking() -> bool:
	return body.velocity.length() > MOVING_SPEED
