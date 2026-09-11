extends CanvasLayer
## The computer in her room: pages through every personality's dossier
## (display_name, dossier_text, portrait), so she knows who she might be
## dealing with before the first day starts. Opened via GameManager, which
## listens for GameEvents.computer_interact_requested.

const PROFILE_PATHS := {
	PersonalityProfile.Personality.FORGETFUL: "res://Resources/Personalities/forgetful.tres",
	PersonalityProfile.Personality.PARANOID: "res://Resources/Personalities/paranoid.tres",
	PersonalityProfile.Personality.OVERWHELMED: "res://Resources/Personalities/overwhelmed.tres",
}

## Fires when the player closes the dossier, i.e. they have actually read it.
## GameManager uses this to end the opening night. Local signal for now - the
## team plans a GameEvents signal for this later.
signal dossier_closed

@onready var portrait_rect: TextureRect = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/PortraitRect
@onready var name_label: Label = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/NameLabel
@onready var dossier_label: Label = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/DossierLabel
@onready var page_label: Label = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/PageLabel
@onready var prev_button: Button = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/Nav/PrevButton
@onready var close_button: Button = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/Nav/CloseButton
@onready var next_button: Button = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/Nav/NextButton

var _profiles: Array[PersonalityProfile] = []
var _page := 0


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	prev_button.pressed.connect(func() -> void: _turn_page(-1))
	next_button.pressed.connect(func() -> void: _turn_page(1))

	_load_profiles()


func open() -> void:
	_page = 0
	_show_page()
	visible = true


func close() -> void:
	if not visible: # guards against a stray close emitting a phantom "read"
		return

	visible = false
	dossier_closed.emit()


# Loaded once from PROFILE_PATHS, so adding a fourth personality is a one-line
# change here and nothing else.
func _load_profiles() -> void:
	for path: String in PROFILE_PATHS.values():
		if not ResourceLoader.exists(path):
			push_warning("Missing personality profile: %s" % path)
			continue

		_profiles.append(load(path))


func _turn_page(step: int) -> void:
	_page = clampi(_page + step, 0, _profiles.size() - 1)
	_show_page()


func _show_page() -> void:
	if _profiles.is_empty():
		name_label.text = "???"
		dossier_label.text = "No dossier data yet."
		portrait_rect.texture = null
		page_label.text = ""
		prev_button.disabled = true
		next_button.disabled = true
		return

	var profile := _profiles[_page]
	portrait_rect.texture = profile.portrait
	name_label.text = profile.display_name
	dossier_label.text = profile.dossier_text
	page_label.text = "%d / %d" % [_page + 1, _profiles.size()]

	prev_button.disabled = _page == 0
	next_button.disabled = _page == _profiles.size() - 1
