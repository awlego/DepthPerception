extends Node2D

# Fish variables
var fish_count = 4
var fish_types = []  # Holds the fish texture paths
var fish_nodes = {}  # Maps texture paths to fish node instances

# UI Variables
var score_label: Label
var depth_label: Label
var camera_target = null
var target_queue = null
var captured_count = 0
var total_targets = 0

# Depth tracking
var current_depth: float = 0.0
var depth_increase_rate: float = 1.0  # Units per second
var max_depth: float = 1000.0  # Maximum depth

# Shader
var depth_shader: ShaderMaterial
var depth_canvas_layer: CanvasLayer
var shader_rect: ColorRect

# Sound variables
var camera_sound: AudioStreamPlayer
var background_music: AudioStreamPlayer

# Camera color settings
var default_camera_color = Color(1, 1, 1, 1)  # White (default)
var success_camera_color = Color(0, 1, 0, 1)  # Green (successful capture)
var fail_camera_color = Color(1, 0, 0, 1)     # Red (failed capture)
var color_reset_time = 0.3  # Time in seconds before color resets

# Flashlight state
var flashlight_on: bool = false
var flashlight = null
var flashlight_auto_activated: bool = false

# Add these variables at the top of your script with other declarations
var parallax_bg: ParallaxBackground
var parallax_layers = []
var parallax_sprites = []

# Called when the node enters the scene tree for the first time.
func _ready():
	# Hide the mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Setup audio
	setup_camera_sound()
	setup_background_music()
	
	# Dynamically load all fish from the fish directory
	fish_types = load_fish_from_directory("res://assets/fish/")
	print("Loaded " + str(fish_types.size()) + " fish types")
	
	# Create fish
	spawn_fish()
	
	# Create camera target/viewfinder
	create_camera_target()
	
	# Create the target fish queue
	create_target_queue()
	
	# Create UI
	create_ui()
	
	# Setup depth shader
	setup_depth_shader()
	
	# Initialize flashlight
	flashlight = load("res://scenes/flashlight.tscn").instantiate()
	add_child(flashlight)
	flashlight.initialize(depth_shader)
	
	# Connect flashlight signals
	flashlight.connect("toggled", _on_flashlight_toggled)
	
	# Setup underwater parallax
	# setup_underwater_parallax()

# Setup the depth shader overlay
func setup_depth_shader():
	# Create shader material
	depth_shader = ShaderMaterial.new()
	depth_shader.shader = load("res://assets/shaders/depth_filter.gdshader")
	depth_shader.set_shader_parameter("depth", current_depth)
	
	# Create a CanvasLayer to overlay the shader
	depth_canvas_layer = CanvasLayer.new()
	depth_canvas_layer.layer = 10  # Put it on top of everything
	add_child(depth_canvas_layer)
	
	# Add a BackBufferCopy node to capture the screen
	var back_buffer = BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	depth_canvas_layer.add_child(back_buffer)
	
	# Create a full-screen ColorRect with the shader
	shader_rect = ColorRect.new()
	shader_rect.material = depth_shader
	shader_rect.size = get_viewport_rect().size
	shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input
	
	# Add to back buffer so it can access screen texture
	back_buffer.add_child(shader_rect)
	
	# Make sure it fills the screen
	var viewport_size_change = get_viewport().size_changed.connect(
		func(): if shader_rect: shader_rect.size = get_viewport_rect().size
	)

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

# Setup the background music
func setup_background_music():
	background_music = AudioStreamPlayer.new()
	background_music.stream = load("res://assets/music/Silent Reverie2.mp3")
	background_music.volume_db = -5  # Slightly quieter than effects
	background_music.autoplay = true  # Start playing right away
	background_music.bus = "Music"  # Optional: If you have a separate audio bus for music
	add_child(background_music)

# Create the camera target/viewfinder
func create_camera_target():
	# Get or create the UI layer
	var ui_layer = null
	for child in get_children():
		if child is CanvasLayer and child.layer == 11:
			ui_layer = child
			break
	
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.layer = 11  # Higher than the shader layer
		add_child(ui_layer)
	
	var camera_target_scene = load("res://scenes/camera_target.tscn")
	camera_target = camera_target_scene.instantiate()
	camera_target.position = get_viewport().get_mouse_position()
	camera_target.connect("fish_captured", _on_fish_captured)
	ui_layer.add_child(camera_target)  # Add to UI layer instead of root

# Create the target fish queue UI
func create_target_queue():
	# Get or create the UI layer
	var ui_layer = null
	for child in get_children():
		if child is CanvasLayer and child.layer == 11:
			ui_layer = child
			break
	
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.layer = 11  # Higher than the shader layer
		add_child(ui_layer)
	
	var queue_scene = load("res://scenes/target_fish_queue.tscn")
	target_queue = queue_scene.instantiate()
	ui_layer.add_child(target_queue)  # Add to UI layer instead of root
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
	# Create a Canvas Layer for UI (higher than the shader layer)
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 11  # Higher than the shader layer (10)
	add_child(ui_layer)
	
	# Create a label to show captured fish count
	score_label = Label.new()
	score_label.text = "Fish photographed: 0/" + str(total_targets)
	score_label.position = Vector2(20, 20)
	ui_layer.add_child(score_label)  # Add to UI layer instead of root
	
	# Create a label to show current depth
	depth_label = Label.new()
	depth_label.text = "Depth: 0m"
	depth_label.position = Vector2(20, 50)  # Position below score label
	ui_layer.add_child(depth_label)  # Add to UI layer instead of root

# Update the depth display
func update_depth_display():
	if depth_label:
		depth_label.text = "Depth: " + str(int(current_depth)) + "m"

# Handler for when a target is completed
func _on_target_completed(fish_type):
	captured_count += 1
	
	# Update score
	if score_label:
		score_label.text = "Fish photographed: " + str(captured_count) + "/" + str(total_targets)
	
	# Check if all targets completed
	if captured_count >= total_targets:
		print("All targets completed!")
		score_label.text = "All fish photographed at " + str(int(current_depth)) + "m depth! You win!"

# Handle fish captured signal
func _on_fish_captured(count):
	# This is just for displaying how many fish are in the viewfinder
	pass

# Handler for flashlight toggle
func _on_flashlight_toggled(is_on):
	flashlight_on = is_on
	# Add any game-specific logic when flashlight toggles

# Handle input events
func _input(event):
	# Play camera sound and take photo when mouse is clicked
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		take_photo()
	
	# Flashlight controls
	if event is InputEventKey and event.pressed:
		# Increase/decrease light radius
		if event.keycode == KEY_UP:
			flashlight.adjust_radius(0.02)
		elif event.keycode == KEY_DOWN:
			flashlight.adjust_radius(-0.02)
			
		# Increase/decrease light intensity
		if event.keycode == KEY_RIGHT:
			flashlight.adjust_intensity(0.1)
		elif event.keycode == KEY_LEFT:
			flashlight.adjust_intensity(-0.1)

		# Adjust light falloff (edge softness)
		if event.keycode == KEY_BRACKETRIGHT:
			flashlight.adjust_falloff(0.1)
		elif event.keycode == KEY_BRACKETLEFT:
			flashlight.adjust_falloff(-0.1)

	# Toggle flashlight on/off
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		flashlight.toggle()

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
	
	# Get the current target fish
	var current_target = null
	if target_queue and target_queue.fish_queue.size() > 0:
		current_target = target_queue.fish_queue[target_queue.current_target_index]
	
	# Check if we captured the specific target fish
	if current_target and current_target in fully_contained_fish:
		# Success! We captured the exact target fish
		camera_target.rect_color = success_camera_color
		camera_target.queue_redraw()
		
		# Complete the target
		target_queue.complete_current_target()
	else:
		# Either no fish or wrong fish - show fail color (red)
		camera_target.rect_color = fail_camera_color
		camera_target.queue_redraw()
	
	# Reset the camera color after a delay
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = color_reset_time
	timer.connect("timeout", reset_camera_color)
	add_child(timer)
	timer.start()

# Reset camera color to default white after photo
func reset_camera_color():
	if camera_target:
		camera_target.rect_color = default_camera_color
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
		
		# Update flashlight position instead of directly updating shader
		if flashlight:
			flashlight.update_position(camera_target.position, get_viewport_rect().size)
	
	# Increase depth over time
	if current_depth < max_depth:
		current_depth += depth_increase_rate * delta
		update_depth_display()
		
		# Update shader depth value
		if depth_shader:
			depth_shader.set_shader_parameter("depth", current_depth)
		
	# Auto-activate flashlight at 25m depth if it's off
	if flashlight and current_depth > 25.0 and not flashlight_auto_activated and not flashlight.flashlight_on:
		flashlight.toggle(true)  # Force ON
		flashlight_auto_activated = true  # Set the flag so this only happens once
		print("Depth reached 25m - flashlight automatically activated")

	# You could add gameplay effects based on depth here
	# For example, making fish move faster or changing the background

# Create a parallax background for underwater scene
func setup_underwater_parallax():
	# Create the main parallax background
	var parallax_bg = ParallaxBackground.new()
	add_child(parallax_bg)
	
	# Far background (distant water/coral)
	var far_layer = ParallaxLayer.new()
	far_layer.motion_scale = Vector2(0.1, 0.1)  # Moves very slowly
	var far_sprite = Sprite2D.new()
	far_sprite.texture = load("res://assets/background-objs/big-rock1.png")
	far_layer.add_child(far_sprite)
	parallax_bg.add_child(far_layer)
	
	# Mid-ground layer (mid-distance plants/rocks)
	var mid_layer = ParallaxLayer.new()
	mid_layer.motion_scale = Vector2(0.4, 0.4)  # Moves at medium speed
	var mid_sprite = Sprite2D.new()
	mid_sprite.texture = load("res://assets/background-objs/coral2.png")
	mid_layer.add_child(mid_sprite)
	parallax_bg.add_child(mid_layer)
	
	# Foreground particles (bubbles/plankton)
	var fore_layer = ParallaxLayer.new()
	fore_layer.motion_scale = Vector2(0.8, 0.8)  # Moves quickly
	var fore_sprite = Sprite2D.new()
	fore_sprite.texture = load("res://assets/background-objs/coral1.png")
	fore_layer.add_child(fore_sprite)
	parallax_bg.add_child(fore_layer)

# Add this new function to load all fish PNGs
func load_fish_from_directory(path):
	var fish_list = []
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Only add PNG files
			if file_name.ends_with(".png"):
				fish_list.append(path + file_name)
			file_name = dir.get_next()
		
		dir.list_dir_end()
	else:
		print("Error: Could not open fish directory at " + path)
	
	return fish_list
