class_name Layers
extends RefCounted
## Named constants for the 2D physics layers declared in project.godot.

## Godot's collision_layer/collision_mask are plain integers (a bitfield: 1,
## 2, 4, 8, 16, ...). Writing raw numbers like `layer = 4` at every call site
## means nobody can tell what a "4" means without opening project.godot, and
## renumbering a layer later means hunting down every literal. Using
## Layers.ENEMY instead is self-documenting and typo-proof.

## `extends RefCounted` because this holds no state - it exists purely to be
## `class_name`-global, so `Layers.INTERACTABLE` works from any script without
## an autoload.

## Never hard-code a collision layer/mask integer anywhere in the project; use
## these instead. The bit values must stay in sync with [layer_names] in
## project.godot.

## Layers 1, 2 and 5 predate this file and MUST NOT be renumbered: the player's
## collision_mask and every solid body's collision_layer = 2 depend on them.

const PLAYER := 1 ## bit 1 - the player body
const WALLS := 2 ## bit 2 - tilemap walls, doors, furniture, stairs
const INTERACTABLE := 4 ## bit 3 - Interactable marker areas (detected, never detecting)
const ENEMY := 8 ## bit 4 - the antagonist body
const STAIRS := 16 ## bit 5 - stairs teleport trigger areas
const HIDING := 32 ## bit 6 - hiding spot trigger areas
const NOISE := 64 ## bit 7 - noise source areas

## The enemy is deliberately NOT on bit 1. Every Area2D authored before this
## refactor uses the default collision_mask of 1, so putting the enemy on bit 4
## makes it invisible to all of them for free:
##   - stairs triggers can never fire on the enemy  -> floor confinement
##   - door/sitable/furniture areas never fire on it -> the speculative "enemy"
##     branches in those scripts stay dormant
## The enemy drives its own interactions instead.
