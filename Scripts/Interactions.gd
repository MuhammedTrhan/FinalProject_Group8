extends Node
## Shared interaction vocabulary. Autoloaded so every domain can name the same
## interaction without depending on another developer's script.

enum InteractionType {
	## No interaction happened. Must stay first so 0 is the falsy default.
	NONE,
	OPEN,
	CLOSE,
	LOCK,
	UNLOCK,
	SITDOWN,
	STANDUP,
	PICKUP,
	## A one-shot tool used from the Inventory UI (e.g. the crowbar swing) -
	## unrelated to the direct Interact/E-press flow. See ToolUser.gd.
	TOOL_USE,
}
