extends Node

const CONFIG_PATH := "user://audio_settings.cfg"

const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var master_db := 0.0
var music_db := 0.0
var sfx_db := 0.0

func _ready():
	_load_settings()
	_apply_all()

# SETTERS
func set_master_db(value: float):
	master_db = clamp(value, -40.0, 0.0)
	AudioServer.set_bus_volume_db(_bus(MASTER_BUS), master_db)
	_save_settings()

func set_music_db(value: float):
	music_db = clamp(value, -40.0, 0.0)
	AudioServer.set_bus_volume_db(_bus(MUSIC_BUS), music_db)
	_save_settings()

func set_sfx_db(value: float):
	sfx_db = clamp(value, -40.0, 0.0)
	AudioServer.set_bus_volume_db(_bus(SFX_BUS), sfx_db)
	_save_settings()

# DEFAULTS
func restore_defaults():
	master_db = 0.0
	music_db = 0.0
	sfx_db = 0.0
	_apply_all()
	_save_settings()

# INTERNAL
func _apply_all():
	AudioServer.set_bus_volume_db(_bus(MASTER_BUS), master_db)
	AudioServer.set_bus_volume_db(_bus(MUSIC_BUS), music_db)
	AudioServer.set_bus_volume_db(_bus(SFX_BUS), sfx_db)

func _bus(name: String) -> int:
	return AudioServer.get_bus_index(name)

# SAVE / LOAD
func _save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master", master_db)
	cfg.set_value("audio", "music", music_db)
	cfg.set_value("audio", "sfx", sfx_db)
	cfg.save(CONFIG_PATH)

func _load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		master_db = cfg.get_value("audio", "master", 0.0)
		music_db = cfg.get_value("audio", "music", 0.0)
		sfx_db = cfg.get_value("audio", "sfx", 0.0)
