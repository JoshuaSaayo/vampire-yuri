extends Node

var story_block = "intro"
var pending_ending: String = ""
var last_ending: String = ""

func set_ending(ending: String):
	pending_ending = ending

func play_ending(ending_name: String):
	last_ending = ending_name
	story_block = "chapter_1_ending"
