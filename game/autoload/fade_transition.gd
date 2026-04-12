extends CanvasLayer

@onready var rect: ColorRect = $FadeRect

@export var fade_time: float = 0.6

var tween: Tween

func _ready():
	rect.modulate.a = 0.0

func fade_in():
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, fade_time)
	await tween.finished

func fade_out():
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, fade_time)
	await tween.finished

func fade_to_scene(scene_path: String):
	await fade_in()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_out()
