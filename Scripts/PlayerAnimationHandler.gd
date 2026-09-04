extends AnimationPlayer
class_name PlayerAnimationHandler


signal interact_anim_finish()

@export var anim_player: AnimationPlayer

var is_interacting: bool = false
var interact_state: String = ""

var last_direction: String = "down"

# These interaction anims should override the default walk/idle animations
var interaction_anims = ["slash", "back_slash", "lock", "sit"]

# Call this function from your Player's _physics_process
func update_animations(velocity: Vector2) -> void:
    var state = "idle"
    
    if is_interacting:
        state = interact_state
    else:
        # If not interacting, determine if we are walking or idling
        if velocity.length() > 0:
            state = "walk"
            # Update the facing direction based on the strongest movement axis
            last_direction = get_facing_direction(velocity)
    
    # 3. Construct the animation name and play it
    var anim_name = state + "_" + last_direction
    play(anim_name)

# Helper function to find the primary direction
func get_facing_direction(velocity: Vector2) -> String:
    if abs(velocity.x) >= abs(velocity.y):
        if velocity.x > 0: return "right"
        else: return "left"
    else:
        if velocity.y > 0: return "down"
        else: return "up"
    

func set_facing_direction(direction: String) -> void:
    if direction in ["up", "down", "left", "right"]:
        last_direction = direction
    
func handle_interaction_anim(interaction: Interactions.InteractionType) -> void:
    is_interacting = true

    match interaction:
        Interactions.InteractionType.OPEN:
            interact_state = "slash"
        Interactions.InteractionType.CLOSE:
            interact_state = "back_slash"
        Interactions.InteractionType.LOCK:
            interact_state = "lock"
        Interactions.InteractionType.UNLOCK:
            interact_state = "lock"
        Interactions.InteractionType.SITDOWN:
            interact_state = "sit"
        Interactions.InteractionType.STANDUP:
            # manually call the animation finished signal for stand up since it doesn't have an animation
            _on_animation_finished("sit_" + last_direction)


func _on_animation_finished(anim_name: StringName) -> void:
    for anim in interaction_anims:
        if anim_name.begins_with(anim):
            is_interacting = false
            interact_state = ""

            emit_signal("interact_anim_finish")
