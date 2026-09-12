extends CanvasLayer
## Volume sliders, opened from both the title screen and the pause menu.
## Draws above them (layer 2) and hands control back via `closed` rather than
## knowing who opened it.

## Whoever opened this listens for it to show itself again.
signal closed

@onready var music_slider: HSlider = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/SfxRow/SfxSlider
@onready var back_button: Button = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/BackButton


func _ready() -> void:
	visible = false

	music_slider.value_changed.connect(Settings.set_music_volume)
	sfx_slider.value_changed.connect(Settings.set_sfx_volume)
	back_button.pressed.connect(close)


func open() -> void:
	# Sliders follow the saved values rather than whatever the scene was
	# authored with.
	music_slider.set_value_no_signal(Settings.music_volume)
	sfx_slider.set_value_no_signal(Settings.sfx_volume)
	visible = true


func close() -> void:
	if not visible:
		return

	Settings.save_settings() # only written on the way out, not per slider tick
	visible = false
	closed.emit()
