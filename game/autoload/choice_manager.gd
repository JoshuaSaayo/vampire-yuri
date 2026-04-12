extends Node

# Global affection tracking
var affection: Dictionary = {
	"Lilith": 0,
}

# Track major story decisions
var story_flags: Dictionary = {}

func add_affection(character: String, amount: int):
	if affection.has(character):
		affection[character] += amount
		print("Added ", amount, " affection for ", character, " (Total: ", affection[character], ")")
	else:
		affection[character] = amount

func get_affection(character: String) -> int:
	return affection.get(character, 0)

func set_flag(flag_name: String, value):
	story_flags[flag_name] = value

func get_flag(flag_name: String):
	return story_flags.get(flag_name, false)

func reset_all():
	affection.clear()
	story_flags.clear()
