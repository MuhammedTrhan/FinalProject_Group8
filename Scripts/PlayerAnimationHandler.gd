extends AnimationPlayer
class_name PlayerAnimationHandler

@export var anim_player: AnimationPlayer
var last_direction: String = "down"

# Call this function from your Player's _physics_process
func update_animations(velocity: Vector2) -> void:
    var state = "idle"
    
    # 1. Determine if we are moving or idling
    if velocity.length() > 0:
        state = "walk"
        # 2. Update the facing direction based on the strongest movement axis
        last_direction = get_facing_direction(velocity)
    
    # 3. Construct the animation name and play it
    var anim_name = state + "_" + last_direction
    play(anim_name)

# Helper function to find the primary direction
func get_facing_direction(velocity: Vector2) -> String:
    if abs(velocity.x) > abs(velocity.y):
        if velocity.x > 0: return "right"
        else: return "left"
    else:
        if velocity.y > 0: return "down"
        else: return "up"