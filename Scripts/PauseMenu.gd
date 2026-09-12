extends CanvasLayer
## Escape menu: resume, options, back to the title screen, quit.
##
## The game-over screen, the win screen and the computer terminal already pause
## the tree for their own reasons. This only ever opens when none of them has,
## and only unpauses what it paused itself - otherwise resuming here would hand
## the house back while the player is supposed to be dead or reading.

@onready var resume_button: Button = $Root/CenterContainer/VBox/ResumeButton
@onready var options_button: Button = $Root/CenterContainer/VBox/OptionsButton
@onready var menu_button: Button = $Root/CenterContainer/VBox/MenuButton
@onready var quit_button: Button = $Root/CenterContainer/VBox/QuitButton


func _ready() -> void:
	visible = false

	resume_button.pressed.connect(close)
	options_button.pressed.connect(_on_options_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	OptionsMenu.closed.connect(_on_options_closed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return

	if visible:
		close()
	elif GameManager.can_pause():
		open()
	else:
		return # somebody else owns the pause, or we're on the title screen

	get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	if not visible:
		return

	visible = false
	get_tree().paused = false


func _on_options_pressed() -> void:
	visible = false # OptionsMenu draws on the layer above; stay paused
	OptionsMenu.open()


func _on_options_closed() -> void:
	if get_tree().paused: # came from here rather than from the title screen
		visible = true


func _on_menu_pressed() -> void:
	visible = false
	GameManager.return_to_main_menu() # unpauses and clears the run's overlays


func _on_quit_pressed() -> void:
	get_tree().quit()
