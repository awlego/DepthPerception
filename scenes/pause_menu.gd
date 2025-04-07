extends CanvasLayer

signal resume_game
signal quit_game

# Store initial volumes
var initial_master_volume = 0
var initial_music_volume = 0
var initial_sfx_volume = 0

func _ready():
	# Hide menu initially
	visible = false
	
	# Connect button signals
	$Panel/VBoxContainer/ResumeButton.pressed.connect(_on_resume_button_pressed)
	$Panel/VBoxContainer/QuitButton.pressed.connect(_on_quit_button_pressed)
	
	# Initialize volume sliders
	setup_volume_sliders()

func setup_volume_sliders():
	# Get slider references
	var master_slider = $Panel/VBoxContainer/MasterVolume
	var music_slider = $Panel/VBoxContainer/MusicVolume
	var sfx_slider = $Panel/VBoxContainer/SoundEffectsVolume
	
	# Get audio bus indices
	var master_bus_idx = AudioServer.get_bus_index("Master")
	var music_bus_idx = AudioServer.get_bus_index("Music")
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	
	# If Music bus doesn't exist, create it
	if music_bus_idx == -1:
		AudioServer.add_bus(1)  # Add at position 1 (after Master)
		AudioServer.set_bus_name(1, "Music")
		music_bus_idx = 1
	
	# If SFX bus doesn't exist, create it
	if sfx_bus_idx == -1:
		AudioServer.add_bus(2)  # Add at position 2 (after Music)
		AudioServer.set_bus_name(2, "SFX")
		sfx_bus_idx = 2
	
	# Store initial volumes in decibels
	initial_master_volume = AudioServer.get_bus_volume_db(master_bus_idx)
	initial_music_volume = AudioServer.get_bus_volume_db(music_bus_idx)
	initial_sfx_volume = AudioServer.get_bus_volume_db(sfx_bus_idx)
	
	# Setup slider ranges
	# From -80 dB (nearly silent) to 0 dB (full volume)
	master_slider.min_value = -80
	master_slider.max_value = 0
	music_slider.min_value = -80
	music_slider.max_value = 0
	sfx_slider.min_value = -80
	sfx_slider.max_value = 0
	
	# Set initial slider values
	master_slider.value = initial_master_volume
	music_slider.value = initial_music_volume
	sfx_slider.value = initial_sfx_volume
	
	# Connect value changed signals
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

func _on_master_volume_changed(value):
	var master_bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_idx, value)
	
	# Mute if at minimum
	if value <= -79:
		AudioServer.set_bus_mute(master_bus_idx, true)
	else:
		AudioServer.set_bus_mute(master_bus_idx, false)

func _on_music_volume_changed(value):
	var music_bus_idx = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music_bus_idx, value)
	
	# Mute if at minimum
	if value <= -79:
		AudioServer.set_bus_mute(music_bus_idx, true)
	else:
		AudioServer.set_bus_mute(music_bus_idx, false)

func _on_sfx_volume_changed(value):
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_bus_idx, value)
	
	# Mute if at minimum
	if value <= -79:
		AudioServer.set_bus_mute(sfx_bus_idx, true)
	else:
		AudioServer.set_bus_mute(sfx_bus_idx, false)

func show_menu():
	visible = true
	
	# Make cursor visible in pause menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_menu():
	visible = false
	
	# Note: We don't hide the cursor here, as the main script will handle this
	# when resuming the game

func _on_resume_button_pressed():
	hide_menu()
	resume_game.emit()

func _on_quit_button_pressed():
	quit_game.emit()
