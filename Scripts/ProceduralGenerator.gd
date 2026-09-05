extends Node
## Generates the run's 4-digit passcode. Puzzles call get_digit(index) for their clue.

const PASSCODE_LENGTH := 4

var _passcode: Array[int] = []


func generate(run_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed

	_passcode.clear()
	for i in PASSCODE_LENGTH:
		_passcode.append(rng.randi_range(0, 9))


func get_digit(index: int) -> int:
	if index < 0 or index >= _passcode.size():
		push_warning("get_digit called with out-of-range index: %d" % index)
		return -1
	return _passcode[index]


func get_passcode() -> Array[int]:
	return _passcode.duplicate()
