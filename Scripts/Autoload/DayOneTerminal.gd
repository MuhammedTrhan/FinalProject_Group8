extends CanvasLayer
## Day-one computer terminal: shows a PersonalityProfile's dossier
## (display_name, dossier_text, portrait). Call open(personality) from
## wherever the physical terminal object lives once it exists.

const PROFILE_PATHS := {
	PersonalityProfile.Personality.FORGETFUL: "res://Resources/Personalities/forgetful.tres",
	PersonalityProfile.Personality.PARANOID: "res://Resources/Personalities/paranoid.tres",
	PersonalityProfile.Personality.OVERWHELMED: "res://Resources/Personalities/overwhelmed.tres",
}

## Fires when the player closes the dossier, i.e. they have actually read it.
## GameManager uses this to end the opening night. Local signal for now - the
## team plans a GameEvents signal for this later.
signal dossier_closed

@onready var name_label: Label = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/NameLabel
@onready var dossier_label: Label = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/DossierLabel
@onready var portrait_rect: TextureRect = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/PortraitRect
@onready var close_button: Button = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/CloseButton


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)


func open(personality: PersonalityProfile.Personality) -> void:
	var path: String = PROFILE_PATHS.get(personality, "")

	if path == "" or not ResourceLoader.exists(path):
		name_label.text = "???"
		dossier_label.text = "No dossier data yet."
		portrait_rect.texture = null
	else:
		var profile: PersonalityProfile = load(path)
		name_label.text = profile.display_name
		dossier_label.text = profile.dossier_text
		portrait_rect.texture = profile.portrait

	visible = true


func close() -> void:
	if not visible: # guards against a stray close emitting a phantom "read"
		return

	visible = false
	dossier_closed.emit()
