extends Control
## The title screen: start a new run, or quit.

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	GameManager.start_new_run()
	get_tree().change_scene_to_file("res://Scenes/main_level.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
