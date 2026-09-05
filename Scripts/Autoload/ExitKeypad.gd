extends CanvasLayer
## Exit-door passcode keypad. Call open() from wherever the physical exit
## door object lives once it exists.

@onready var code_input: LineEdit = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/CodeInput
@onready var confirm_button: Button = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/ConfirmButton


func _ready() -> void:
	visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)
	code_input.text_changed.connect(_on_code_text_changed)


func open() -> void:
	code_input.text = ""
	visible = true


func close() -> void:
	visible = false


# LineEdit doesn't restrict to digits on its own, so strip anything else as the player types.
func _on_code_text_changed(new_text: String) -> void:
	var digits_only := ""
	for c in new_text:
		if c >= "0" and c <= "9":
			digits_only += c

	if digits_only != new_text:
		code_input.text = digits_only
		code_input.caret_column = digits_only.length()


func _on_confirm_pressed() -> void:
	var entered := code_input.text

	if entered.length() != ProceduralGenerator.PASSCODE_LENGTH:
		GameEvents.message_requested.emit("Enter all %d digits." % ProceduralGenerator.PASSCODE_LENGTH)
		return

	var correct_digits := ProceduralGenerator.get_passcode()
	for i in entered.length():
		if int(entered[i]) != correct_digits[i]:
			GameEvents.message_requested.emit("Incorrect code.")
			return

	close()
	WinScreen.show_win()
