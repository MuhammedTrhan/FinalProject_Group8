class_name EnemyAnimationHandler
extends AnimationPlayer
## Drives the LPC spritesheet animations from a velocity vector - the enemy
## counterpart of PlayerAnimationHandler.gd, same animation vocabulary
## ("<state>_<direction>") and the same interaction-pose locking - plus
## per-personality spritesheet retargeting.

signal interact_anim_finish()

var is_interacting: bool = false
var interact_state: String = ""
var last_direction: String = "down"

var interaction_anims: Array[String] = ["slash", "back_slash", "lock", "sit"]


func update_animations(velocity: Vector2) -> void:
	var state := "idle"

	if is_interacting:
		state = interact_state
	elif velocity.length() > 0:
		state = "walk"
		last_direction = get_facing_direction(velocity)

	play(state + "_" + last_direction)


func get_facing_direction(velocity: Vector2) -> String:
	if abs(velocity.x) >= abs(velocity.y):
		return "right" if velocity.x > 0 else "left"
	return "down" if velocity.y > 0 else "up"


func set_facing_direction(direction: String) -> void:
	if direction in ["up", "down", "left", "right"]:
		last_direction = direction


## The cardinal Vector2 matching last_direction. Perception snaps its vision
## cone to this - see Perception.gd.
func get_facing_vector() -> Vector2:
	match last_direction:
		"up": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		_: return Vector2.DOWN


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
		Interactions.InteractionType.SITDOWN:
			interact_state = "sit"
		Interactions.InteractionType.STANDUP:
			end_interaction()


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


## Swaps every animation's Sprite2D:texture key to `profile`'s matching
## sheet. Called once whenever the active personality changes.
func apply_personality(profile: PersonalityProfile) -> void:
	var lib: AnimationLibrary = get_animation_library("").duplicate(true)
	for anim_name in lib.get_animation_list():
		var anim: Animation = lib.get_animation(anim_name)
		for t in anim.get_track_count():
			if anim.track_get_path(t) == NodePath("Sprite2D:texture"):
				anim.track_set_key_value(t, 0, profile.get_sheet_for_animation(anim_name))
	remove_animation_library("")
	add_animation_library("", lib)
