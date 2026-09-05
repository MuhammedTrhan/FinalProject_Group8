class_name PlayerAnimationHandler
extends AnimationPlayer
## Drives the LPC spritesheet animations from a velocity vector, and locks the
## character into an interaction pose until that pose finishes.
##
## Animations are named "<state>_<direction>", e.g. "walk_left", "slash_up".


## Emitted when an interaction pose has finished and the actor may move again.
signal interact_anim_finish()

var is_interacting: bool = false
var interact_state: String = ""

var last_direction: String = "down"

## Interaction poses override the default walk/idle animations. Matched by
## prefix against the finished animation's name.
var interaction_anims: Array[String] = ["slash", "back_slash", "lock", "sit"]


## Call this from the actor's _physics_process.
func update_animations(velocity: Vector2) -> void:
	var state := "idle"

	if is_interacting:
		state = interact_state
	else:
		# Not interacting: walking or idling.
		if velocity.length() > 0:
			state = "walk"
			# Face the strongest movement axis.
			last_direction = get_facing_direction(velocity)

	play(state + "_" + last_direction)


func get_facing_direction(velocity: Vector2) -> String:
	if abs(velocity.x) >= abs(velocity.y):
		return "right" if velocity.x > 0 else "left"
	return "down" if velocity.y > 0 else "up"


func set_facing_direction(direction: String) -> void:
	if direction in ["up", "down", "left", "right"]:
		last_direction = direction


func handle_interaction_anim(interaction: Interactions.InteractionType) -> void:
	if interaction == Interactions.InteractionType.NONE:
		return

	is_interacting = true

	match interaction:
		Interactions.InteractionType.OPEN:
			interact_state = "slash"
		Interactions.InteractionType.CLOSE:
			interact_state = "back_slash"
		Interactions.InteractionType.LOCK, Interactions.InteractionType.UNLOCK:
			interact_state = "lock"
		Interactions.InteractionType.PICKUP:
			interact_state = "slash"
		Interactions.InteractionType.SITDOWN:
			interact_state = "sit"
		Interactions.InteractionType.STANDUP:
			# Standing up has no animation of its own, and it cannot wait for
			# animation_finished either: the sit_* animations are authored with
			# loop_mode = LOOP_LINEAR (a single static pose), so
			# animation_finished NEVER fires for them.
			#
			# Releasing the lock here is therefore the ONLY way the player ever
			# regains control after sitting down. Do not "simplify" this away.
			end_interaction()


## Clears the interaction lock and tells the actor it may move again.
func end_interaction() -> void:
	if not is_interacting:
		return

	is_interacting = false
	interact_state = ""
	interact_anim_finish.emit()


func _on_animation_finished(anim_name: StringName) -> void:
	for anim in interaction_anims:
		if anim_name.begins_with(anim):
			end_interaction()
			return
