extends Node
## Main scene for rendering the trailer. Starting a run swaps this scene out
## for the level, so the director is parked under the root first.
##
##   godot --path . --write-movie Trailer.avi --fixed-fps 30 res://Scenes/Trailer/trailer.tscn
##
## Options go after the scene, behind `--`:
##   --cut=60       the 60 s story-driven cut instead of the 30 s teaser
##   --shots=<dir>  also dump a PNG every half second, for checking shots
##                  without watching the whole video

const TeaserDirector := preload("res://Scripts/Trailer/TrailerDirector.gd")
const LongDirector := preload("res://Scripts/Trailer/TrailerDirectorLong.gd")


func _ready() -> void:
	var director := LongDirector if "--cut=60" in OS.get_cmdline_user_args() else TeaserDirector
	get_tree().root.add_child.call_deferred(director.new())
	GameManager.start_new_run.call_deferred()
