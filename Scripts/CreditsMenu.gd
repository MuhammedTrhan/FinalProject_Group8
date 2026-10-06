extends Control
## Scrollable credits page, opened from the title screen. The text is built
## once from CreditsData and links open in the system browser.

const CreditsData := preload("res://Scripts/CreditsData.gd")
const GOLD := "#d4ad59"
const DIM := "#a89f8c"

@onready var text: RichTextLabel = $CenterContainer/PanelContainer/MarginContainer/VBox/Scroll/Text
@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBox/BackButton

var _warming := false
var _url_regex := RegEx.create_from_string(r"https?://[^\s\[\]]+")


func _ready() -> void:
	visible = false

	text.meta_clicked.connect(_on_meta_clicked)
	back_button.pressed.connect(close)
	text.text = _build_text()
	_warm_up()


## A RichTextLabel only lays its text out once it is shown, which took seconds
## on the first open. Lay it out now instead, invisibly and off the main thread
## (the label is `threaded`), then hide it again.
func _warm_up() -> void:
	_warming = true
	modulate.a = 0.0
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	visible = true
	await text.finished
	if _warming:
		_warming = false
		visible = false
		_show_normally()


func _show_normally() -> void:
	modulate.a = 1.0
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED


func open() -> void:
	_warming = false # opened before warm-up finished: just keep it showing
	_show_normally()
	visible = true
	back_button.grab_focus()


func close() -> void:
	visible = false


func _build_text() -> String:
	var out := ""
	for section: Dictionary in CreditsData.SECTIONS:
		out += "[center][font_size=34][color=%s]%s[/color][/font_size][/center]\n\n" % [GOLD, section.title]
		for entry: Dictionary in section.entries:
			out += _build_entry(entry) + "\n"
		out += "\n"
	return out


func _build_entry(entry: Dictionary) -> String:
	var out := "[font_size=26][color=%s]%s[/color][/font_size]\n" % [GOLD, _escape(entry.name)]
	if entry.creator != "":
		out += "by %s\n" % _escape(entry.creator)
	for link: String in entry.links:
		out += "[url=%s]%s[/url]\n" % [link, link]
	if entry.license != "":
		out += "License: %s\n" % _escape(entry.license)
	if entry.note != "":
		out += "[font_size=20][color=%s]%s[/color][/font_size]\n" % [DIM, _linkify(_escape(entry.note))]
	return out


## Stops "[" in credit text being read as BBCode.
func _escape(s: String) -> String:
	return s.replace("[", "[lb]")


## Turns bare URLs inside a note into clickable links.
func _linkify(s: String) -> String:
	var out := ""
	var last := 0
	for m: RegExMatch in _url_regex.search_all(s):
		out += s.substr(last, m.get_start() - last)
		out += "[url=%s]%s[/url]" % [m.get_string(), m.get_string()]
		last = m.get_end()
	return out + s.substr(last)


func _on_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))
