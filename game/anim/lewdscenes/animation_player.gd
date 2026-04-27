extends SpineSprite

@onready var sfx_moan: AudioStreamPlayer = $sfx_moan

var character_moans: Dictionary = {
	"elara": [
		preload("res://anim/lewd_assets/lilith_ls_1/sounds/elara_moan1.wav"),
		preload("res://anim/lewd_assets/lilith_ls_1/sounds/elara_moan2.wav"),
		preload("res://anim/lewd_assets/lilith_ls_1/sounds/elara_moan3.wav")
	]
}

@export var character: String = "elara"
@export var preview_mode: bool = false

func _ready() -> void:
	get_animation_state().set_animation("animation", true, 0)
	
	# Connect to the Sprite's signal, not the AnimationState's
	self.animation_event.connect(_on_animation_event)



func _on_animation_event(spine_sprite: SpineSprite, animation_state: SpineAnimationState, track_entry: SpineTrackEntry, event: SpineEvent) -> void:
	# Use get_data().get_event_name() to check the name defined in Spine
	if event.get_data().get_event_name() == "moan":
		play_random_moan()
		
func play_random_moan():
	if not character_moans.has(character):
		return
	
	var moans = character_moans[character]
	if moans.is_empty():
		return
	
	var random_sound = moans.pick_random()
	
	sfx_moan.stream = random_sound
	sfx_moan.play()
