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
	
	# Ensure all audio buses exist
	var master_bus_idx = AudioServer.get_bus_index("Master")
	
	# Create Music bus if it doesn't exist
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx == -1:
		AudioServer.add_bus()
		music_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus_idx, "Music")
		# Make sure Music sends to Master
		AudioServer.set_bus_send(music_bus_idx, "Master")
		print("Created Music bus at index", music_bus_idx)
	
	# Create SFX bus if it doesn't exist
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx == -1:
		AudioServer.add_bus()
		sfx_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_bus_idx, "SFX")
		# Make sure SFX sends to Master
		AudioServer.set_bus_send(sfx_bus_idx, "Master")
		print("Created SFX bus at index", sfx_bus_idx)
	
	# Initialize bus volumes if they're at defaults
	if AudioServer.get_bus_volume_db(music_bus_idx) <= -80:
		AudioServer.set_bus_volume_db(music_bus_idx, -5)  # Default music to slightly lower
	
	if AudioServer.get_bus_volume_db(sfx_bus_idx) <= -80:
		AudioServer.set_bus_volume_db(sfx_bus_idx, 0)  # Default SFX to normal volume
	
	# Store initial volumes in decibels
	initial_master_volume = AudioServer.get_bus_volume_db(master_bus_idx)
	initial_music_volume = AudioServer.get_bus_volume_db(music_bus_idx)
	initial_sfx_volume = AudioServer.get_bus_volume_db(sfx_bus_idx)
	
	# Setup slider ranges and values
	master_slider.min_value = -40  # Changed from -80 to be more user-friendly
	master_slider.max_value = 0
	master_slider.value = initial_master_volume
	
	music_slider.min_value = -40
	music_slider.max_value = 0
	music_slider.value = initial_music_volume
	
	sfx_slider.min_value = -40
	sfx_slider.max_value = 0
	sfx_slider.value = initial_sfx_volume
	
	# Connect signals
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# Print debug info
	print("Audio bus setup complete:")
	print("- Master bus: ", master_bus_idx, " Volume: ", AudioServer.get_bus_volume_db(master_bus_idx))
	print("- Music bus: ", music_bus_idx, " Volume: ", AudioServer.get_bus_volume_db(music_bus_idx))
	print("- SFX bus: ", sfx_bus_idx, " Volume: ", AudioServer.get_bus_volume_db(sfx_bus_idx))

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
