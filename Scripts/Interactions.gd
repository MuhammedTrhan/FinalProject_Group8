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
}
