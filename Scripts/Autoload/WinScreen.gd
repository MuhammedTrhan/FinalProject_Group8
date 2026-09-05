extends CanvasLayer
## Full-screen "you escaped" card, shown once ExitKeypad accepts the code.

@onready var menu_button: Button = $Root/CenterContainer/VBoxContainer/MenuButton


func _ready() -> void:
	visible = false
	menu_button.pressed.connect(_on_menu_pressed)


func show_win() -> void:
	visible = true


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
