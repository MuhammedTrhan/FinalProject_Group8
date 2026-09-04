extends StaticBody2D

signal sit_triggered(isSeated: bool, sitPosition: Vector2, standPosition: Vector2)

@onready var info_label = $InfoLabel
@onready var stand_up_point = $StandUpMarker
@onready var sit_down_point = $SitDownMarker

var player_inside: bool = false
var is_occupied: bool = false
# Holds bodies: {"player": body_ref, "enemy": body_ref}
var interacting_bodies: Dictionary = {}
var occupant: Node2D = null


func _ready() -> void:
    if not player_inside:
        info_label.hide()
    else:
        info_label.show()

func _on_interraction_area_body_entered(body: Node2D) -> void:
    var body_key: String

    if body.is_in_group("player"):
        body_key = "player"
        player_inside = true

        if not is_occupied:
            info_label.show()
    else:
        body_key = "enemy"
    
    interacting_bodies[body_key] = body

    if body.has_method("on_sit_triggered"):
        sit_triggered.connect(body.on_sit_triggered)

func _on_interraction_area_body_exited(body: Node2D) -> void:
    var body_key: String
    
    if body.is_in_group("player"):
        body_key = "player"
        player_inside = false
        info_label.hide()
    else:
        body_key = "enemy"

    # Keep the reference if they are sitting, otherwise they can't stand up
    if body_key in interacting_bodies and interacting_bodies[body_key] == body and not is_occupied:
        interacting_bodies.erase(body_key)
    
    if body.has_method("on_sit_triggered") and sit_triggered.is_connected(body.on_sit_triggered):
        sit_triggered.disconnect(body.on_sit_triggered)

func _unhandled_input(event: InputEvent) -> void:
    if not player_inside or not "player" in interacting_bodies:
        return
    
    var player_body = interacting_bodies["player"]
    if not is_instance_valid(player_body):
        return

    # IF SITTING: Listen for 'action' or movement keys to stand up
    if is_occupied and occupant == player_body:
        if event.is_action_pressed("action") or _is_movement_key(event):
            stand_up()
            
    # IF NOT SITTING: Listen for 'action' to sit down
    elif player_inside and not is_occupied:
        if event.is_action_pressed("action"):
            sit_down(player_body)

func sit_down(character: Node2D) -> void:
    is_occupied = true
    occupant = character
    info_label.hide()

    # The chair dynamically ignores collision with whoever sat in it
    occupant.add_collision_exception_with(self)
    
    sit_triggered.emit(true, sit_down_point.global_position, stand_up_point.global_position)

func stand_up() -> void:
    if is_instance_valid(occupant):
        # Restore collision for the occupant before clearing the reference
        occupant.remove_collision_exception_with(self)
    
    is_occupied = false
    
    sit_triggered.emit(false, sit_down_point.global_position, stand_up_point.global_position)
        
    if player_inside:
        info_label.show()

func _is_movement_key(event: InputEvent) -> bool:
    return event.is_action_pressed("up") or event.is_action_pressed("down") or event.is_action_pressed("left") or event.is_action_pressed("right")