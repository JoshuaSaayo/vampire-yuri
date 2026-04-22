extends Node

# Global affection tracking - only Lilith for now
var affection: Dictionary = {
	"Lilith": 0
}

# Track major story decisions
var story_flags: Dictionary = {}

func add_affection(character: String, amount: int):
	if affection.has(character):
		affection[character] += amount
		print("✅ Added ", amount, " affection for ", character, " (Total: ", affection[character], ")")
	else:
		affection[character] = amount
		print("✅ Created new affection for ", character, " with value: ", amount)

func get_affection(character: String) -> int:
	var value = affection.get(character, 0)
	print("📊 Getting affection for ", character, ": ", value)
	return value

func set_flag(flag_name: String, value):
	story_flags[flag_name] = value
	print("🚩 Flag set: ", flag_name, " = ", value)

func get_flag(flag_name: String):
	return story_flags.get(flag_name, false)

func reset_all():
	affection.clear()
	story_flags.clear()
	print("🔄 All affection and flags reset")

# Get ending based on affection (only Lilith)
func get_ending() -> String:
	var lilith_affection = get_affection("Lilith")
	print("🎯 Checking ending with Lilith affection: ", lilith_affection)
	
	if lilith_affection >= 2:
		print("✨ GOOD ENDING triggered (affection: ", lilith_affection, " >= 2)")
		return "lewd_ending"
	else:
		print("⚠️ NEUTRAL ENDING triggered (affection: ", lilith_affection, " < 2)")
		return "neutral_ending"
