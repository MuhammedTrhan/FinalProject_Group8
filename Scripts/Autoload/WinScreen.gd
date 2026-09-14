extends CanvasLayer
## Full-screen "you escaped" card, shown once ExitKeypad accepts the code.

@onready var menu_button: Button = $Root/CenterContainer/VBoxContainer/MenuButton


func _ready() -> void:
	visible = false
	menu_button.pressed.connect(_on_menu_pressed)


func show_win() -> void:
	Hud.visible = false # the run is over; its readouts draw above this screen
	visible = true


func _on_menu_pressed() -> void:
	GameManager.return_to_main_menu()
