extends CanvasLayer
## Full-screen game-over overlay shown when GameEvents.player_caught fires.

const REASON_TEXT := {
	&"seen": "You were seen.",
	&"too_close": "You got too close.",
	&"noise": "You made too much noise.",
	&"timeout": "You ran out of time.",
	&"touched": "You were caught.",
}

@onready var reason_label: Label = $Root/CenterContainer/VBoxContainer/ReasonLabel
@onready var menu_button: Button = $Root/CenterContainer/VBoxContainer/MenuButton


func _ready() -> void:
	visible = false
	menu_button.pressed.connect(_on_menu_pressed)
	GameEvents.player_caught.connect(_on_player_caught)


func _on_player_caught(reason: StringName) -> void:
	reason_label.text = REASON_TEXT.get(reason, "You were caught.")
	visible = true


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
