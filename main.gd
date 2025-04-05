extends Node2D

# Fish variables
var fish_count = 4
var fish_types = []  # Holds the fish texture paths
var fish_nodes = {}  # Maps texture paths to fish node instances

# UI Variables
var score_label: Label
var camera_target = null
var target_queue = null
var captured_count = 0
var total_targets = 0

# Sound variables
var camera_sound: AudioStreamPlayer

# Camera color settings
var regular_camera_color = Color(1, 0, 0, 1)  # Red
var success_camera_color = Color(0, 1, 0, 1)  # Green
var color_reset_time = 0.3  # Time in seconds before color resets (reduced from 0.5)

# Called when the node enters the scene tree for the first time.
func _ready():
	# Hide the mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Setup camera shutter sound
	setup_camera_sound()
	
	# Initialize fish types
	fish_types = [
		"res://assets/fish/fish1.png",
		"res://assets/fish/fish2.png",
		"res://assets/fish/fish3.png",
		"res://assets/fish/fish4.png"
	]
	
	# Create fish
	spawn_fish()
	
	# Create camera target/viewfinder
	create_camera_target()
	
	# Create the target fish queue
	create_target_queue()
	
	# Create UI
	create_ui()

# Show the mouse cursor when quitting or losing focus
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Restore mouse cursor when closing the game
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Also restore cursor when losing focus (alt-tab, etc)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# Hide it again when focus returns
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

# Setup the camera shutter sound
func setup_camera_sound():
	camera_sound = AudioStreamPlayer.new()
	camera_sound.stream = load("res://assets/sounds/camera-shutter-1.mp3")
	camera_sound.volume_db = 0  # Normal volume, adjust as needed
	add_child(camera_sound)

# Create the camera target/viewfinder
func create_camera_target():
	var camera_target_scene = load("res://scenes/camera_target.tscn")
	camera_target = camera_target_scene.instantiate()
	camera_target.position = get_viewport().get_mouse_position()
	camera_target.connect("fish_captured", _on_fish_captured)
	add_child(camera_target)

# Create the target fish queue UI
func create_target_queue():
	var queue_scene = load("res://scenes/target_fish_queue.tscn")
	target_queue = queue_scene.instantiate()
	add_child(target_queue)
	target_queue.connect("target_completed", _on_target_completed)
	
	# Generate random target sequence using the available fish types
	var target_sequence = []
	var available_types = fish_types.duplicate()
	
	# Create a random sequence of 6 target fish
	for i in range(6):
		var random_index = randi() % available_types.size()
		target_sequence.append(available_types[random_index])
	
	# Set the targets in the queue
	target_queue.set_target_fish(target_sequence)
	total_targets = target_sequence.size()

# Spawn fish around the scene
func spawn_fish():
	var screen_size = get_viewport_rect().size
	
	for i in range(fish_types.size()):
		var fish_scene = load("res://scenes/fish.tscn")
		var fish = fish_scene.instantiate()
		fish.texture_path = fish_types[i]
		
		# Random starting position
		fish.position = Vector2(
			randf_range(50, screen_size.x - 50),
			randf_range(50, screen_size.y - 50)
		)
		
		add_child(fish)
		
		# Store reference to the fish
		fish_nodes[fish_types[i]] = fish

# Create UI elements
func create_ui():
	# Create a label to show captured fish count
	score_label = Label.new()
	score_label.text = "Fish photographed: 0/" + str(total_targets)
	score_label.position = Vector2(20, 20)
	add_child(score_label)

# Handler for when a target is completed
func _on_target_completed(fish_type):
	captured_count += 1
	
	# Update score
	if score_label:
		score_label.text = "Fish photographed: " + str(captured_count) + "/" + str(total_targets)
	
	# Check if all targets completed
	if captured_count >= total_targets:
		print("All targets completed!")
		score_label.text = "All fish photographed! You win!"

# Handle fish captured signal
func _on_fish_captured(count):
	# This is just for displaying how many fish are in the viewfinder
	pass

# Handle input events
func _input(event):
	# Play camera sound and take photo when mouse is clicked
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		take_photo()

# Take a photo with the camera
func take_photo():
	if not camera_target:
		return
		
	# Play camera shutter sound
	if camera_sound:
		camera_sound.play()
	
	# Always create a flash effect for any photo
	create_flash_effect()
	
	# Check if any fish are FULLY in the viewfinder for successful capture
	var fully_contained_fish = []
	
	# Get all fish fully in viewfinder
	for texture_path in fish_nodes:
		var fish = fish_nodes[texture_path]
		if camera_target.is_fish_fully_in_viewfinder(fish):
			fully_contained_fish.append(texture_path)
	
	if fully_contained_fish.size() > 0:
		# Success! Change camera color to green
		camera_target.rect_color = success_camera_color
		camera_target.queue_redraw()
		
		# Check if current target fish is fully in the viewfinder
		var current_target = null
		if target_queue and target_queue.fish_queue.size() > 0:
			current_target = target_queue.fish_queue[target_queue.current_target_index]
		
		if current_target and current_target in fully_contained_fish:
			# Correct target photographed!
			target_queue.complete_current_target()
		
		# Reset the camera color after a delay
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = color_reset_time
		timer.connect("timeout", reset_camera_color)
		add_child(timer)
		timer.start()

# Reset camera color to red after photo
func reset_camera_color():
	if camera_target:
		camera_target.rect_color = regular_camera_color
		camera_target.queue_redraw()
	
	# Remove the timer
	for child in get_children():
		if child is Timer and child.is_connected("timeout", reset_camera_color):
			child.queue_free()

# Create a flash effect when taking a photo
func create_flash_effect():
	if not camera_target:
		return
		
	# Create a white rectangle for the flash, limited to the camera viewfinder
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.7)  # Semi-transparent white
	
	# Match the size of the camera viewfinder
	flash.size = camera_target.rect_size
	
	# Position it relative to the camera target
	flash.position = -camera_target.rect_size / 2  # Center it on camera target
	
	# Add the flash to the camera target so it moves with it
	camera_target.add_child(flash)
	
	# Fade out the flash
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.2)  # Fade out over 0.2 seconds
	tween.tween_callback(flash.queue_free)  # Remove flash when done

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Update camera target position to follow mouse
	if camera_target:
		camera_target.position = get_viewport().get_mouse_position()
