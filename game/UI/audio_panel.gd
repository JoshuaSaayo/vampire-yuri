extends Panel

@onready var master_slider: HSlider = $Master/MasterSlider
@onready var music_slider: HSlider = $Music/MusicSlider
@onready var sfx_slider: HSlider = $Sounds/SFXSlider
@onready var restore_btn: Button = $RestoreBtn

func _ready():
	# Slider ranges
	for slider in [master_slider, music_slider, sfx_slider]:
		slider.min_value = -40
		slider.max_value = 0
		slider.step = 0.1

	# Load current values
	master_slider.value = AudioManager.master_db
	music_slider.value = AudioManager.music_db
	sfx_slider.value = AudioManager.sfx_db

	# Connect signals
	master_slider.value_changed.connect(AudioManager.set_master_db)
	music_slider.value_changed.connect(AudioManager.set_music_db)
	sfx_slider.value_changed.connect(AudioManager.set_sfx_db)

	restore_btn.pressed.connect(_on_restore_defaults)


func _on_restore_defaults():
	AudioManager.restore_defaults()
	master_slider.value = AudioManager.master_db
	music_slider.value = AudioManager.music_db
	sfx_slider.value = AudioManager.sfx_db
