extends Node2D

@onready var sprite: TextureRect = $Sprite

func set_expression(expression_name: String):
	var path = "res://assets/sprites/%s.png" % expression_name
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	else:
		push_warning("Sprite not found: " + path)
		sprite.texture = null

func show_sprite():
	visible = true

func hide_sprite():
	visible = false
