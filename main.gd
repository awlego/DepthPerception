extends Node2D

# UI Variables
var score_label: Label
var depth_label: Label
var camera_target = null
var target_queue = null
var total_targets = 0
var captured_count = 0
var fps_label: Label

# Depth tracking
var current_depth = 0.0  # Single source of truth for depth
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

# Coral wall
var coral_wall = null

# Fish manager
var fish_manager

# God rays
var god_rays = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# Hide the mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Setup audio
	setup_camera_sound()
	# setup_background_music()
	
	# Create camera target/viewfinder
	create_camera_target()
	
	# Create UI
	create_ui()
	
	# Setup depth shader
	setup_depth_shader()
	
	# Initialize coral wall
	var coral_wall_scene = load("res://scenes/coral_wall.tscn")
	coral_wall = coral_wall_scene.instantiate()
	add_child(coral_wall)
	
	# Now initialize flashlight AFTER both the depth filter and coral wall exist
	initialize_flashlight()
	
	# Initialize fish manager
	fish_manager = FishManager.new()
	add_child(fish_manager)

	# Create the target fish queue
	create_target_queue()

	# Initialize the god rays
	initialize_god_rays()

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
	
	# Generate target sequence using fish from the fish manager
	if fish_manager:
		var target_sequence = []
		var available_fish = []
		
		# Define the depth range for available targets (current depth ±30m)
		var min_depth = max(0, current_depth - 30)
		var max_depth = current_depth + 30
		
		# Get all currently visible fish (on screen) and fish in the valid depth range
		var visible_fish_set = {}  # Using a dictionary as a set to avoid duplicates
		
		# First, check active fish that are already on screen
		for fish in fish_manager.active_fish:
			if is_instance_valid(fish) and fish.visible:
				visible_fish_set[fish.texture_path] = true
		
		# Then add fish from the database that are in our depth range
		for fish_data in fish_manager.fish_database:
			# Check if this fish type can appear in our current depth range
			var fish_min_depth = fish_data.depth_range.x
			var fish_max_depth = fish_data.depth_range.y
			
			# If there's overlap between our depth range and the fish's range
			if (fish_min_depth <= max_depth and fish_max_depth >= min_depth):
				visible_fish_set[fish_data.texture_path] = true
		
		# Convert set to array
		for fish_path in visible_fish_set:
			available_fish.append(fish_path)
		
		# If we have fish available, create a sequence
		if available_fish.size() > 0:
			# Create a random sequence of up to 6 target fish
			var num_targets = min(6, available_fish.size())
			
			# Shuffle the available fish
			available_fish.shuffle()
			
			# Take the first 6 (or fewer)
			for i in range(num_targets):
				target_sequence.append(available_fish[i])
			
			# Set the targets in the queue
			target_queue.set_target_fish(target_sequence)
			total_targets = target_sequence.size()
			
			# Update the score label
			if score_label:
				score_label.text = "Fish photographed: 0/" + str(total_targets)
		else:
			# No fish available, show an error or default message
			print("Warning: No fish available in current depth range")
			if score_label:
				score_label.text = "No target fish at current depth"

# Spawn fish around the scene
func spawn_fish():
	# This function is no longer needed as the fish_manager handles fish spawning
	# If you want to keep it for manual spawning, here's an updated version:
	
	if fish_manager and fish_manager.fish_database.size() > 0:
		# Let fish manager handle normal spawning
		fish_manager.spawn_fish()
	else:
		print("Warning: Cannot spawn fish, fish manager not initialized or has empty database")

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
	
	# Create an FPS counter label
	fps_label = Label.new()
	fps_label.text = "FPS: 0"
	fps_label.position = Vector2(20, 80)  # Position below depth label
	fps_label.modulate = Color(1, 1, 0)  # Yellow color for visibility
	ui_layer.add_child(fps_label)

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
	# OR if the viewfinder is covered by a target fish by more than 90%
	var captured_fish = []
	
	# Get all fish in the scene and check if they're captured
	var fish_in_scene = get_tree().get_nodes_in_group("fish")
	for fish in fish_in_scene:
		if camera_target.is_valid_fish_capture(fish):
			if fish.texture_path:
				captured_fish.append(fish.texture_path)
				
				# Optional: Add some visual feedback for which fish was captured
				print("Captured fish: " + fish.fish_name + " - Coverage: " + 
					  str(int(camera_target.calculate_viewfinder_coverage(fish))) + "%")
	
	# Get the current target fish
	var current_target = null
	if target_queue and target_queue.fish_queue.size() > 0:
		current_target = target_queue.fish_queue[target_queue.current_target_index]
	
	# Check if we captured the specific target fish
	if current_target and current_target in captured_fish:
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
		
		# Update coral wall with new depth
		if coral_wall:
			coral_wall.update_depth(current_depth)
		
		# Update god rays with current depth
		if god_rays:
			god_rays.update_depth(current_depth)
	
	# Auto-activate flashlight at 25m depth if it's off
	if flashlight and current_depth > 25.0 and not flashlight_auto_activated and not flashlight.flashlight_on:
		flashlight.toggle(true)  # Force ON
		flashlight_auto_activated = true  # Set the flag so this only happens once
		print("Depth reached 25m - flashlight automatically activated")

	# Update FPS counter
	if fps_label:
		fps_label.text = "FPS: " + str(Engine.get_frames_per_second())

	# Update coral wall depth
	if has_node("CoralWall"):
		$CoralWall.update_depth(current_depth)
	
	# Pass the single depth value to all systems that need it
	if fish_manager:
		fish_manager.update_depth(current_depth)

	# You could add gameplay effects based on depth here
	# For example, making fish move faster or changing the background

	# Update depth
	if current_depth < max_depth:
		var previous_depth = current_depth
		current_depth += depth_increase_rate * delta
		update_depth_display()
		
		# Check if we've crossed a 30m boundary
		if int(previous_depth / 30) != int(current_depth / 30):
			refresh_target_queue()

# Refresh the target queue to match current depth
# Call this periodically or when significant depth changes occur
func refresh_target_queue():
	# Don't refresh if all targets have been completed
	if captured_count >= total_targets and total_targets > 0:
		return
	
	# Only refresh every 30m of depth change
	var depth_interval = 30
	if int(current_depth) % depth_interval != 0:
		return
		
	print("Refreshing target queue at depth: " + str(int(current_depth)) + "m")
	
	# Reset the target queue
	if target_queue:
		target_queue.clear_queue()
		captured_count = 0
		
		create_target_queue()  # This will create new targets based on current depth


# New method to initialize flashlight
func initialize_flashlight():
	# Initialize flashlight
	flashlight = load("res://scenes/flashlight.tscn").instantiate()
	add_child(flashlight)
	
	# Check that DepthFilter exists
	var depth_filter = get_node_or_null("DepthFilter")
	if not depth_filter:
		print("WARNING: DepthFilter node not found, using shader_rect material instead")
		depth_filter = shader_rect # Use the ColorRect from setup_depth_shader
	
	# Get references to both shaders
	var depth_filter_shader = depth_filter.material
	
	# Verify coral_wall exists
	if not coral_wall:
		push_error("Coral wall not found or initialized properly")
		return
		
	# Get coral materials
	var coral_shader_materials = coral_wall.get_shader_materials()
	if coral_shader_materials.size() == 0:
		print("WARNING: No coral shader materials found")
	
	# Initialize the flashlight with the depth filter shader
	if depth_filter_shader:
		flashlight.initialize(depth_filter_shader)
		print("Flashlight initialized with depth filter shader")
	else:
		push_error("No depth filter shader found to initialize flashlight")
		return
	
	# Add all coral materials to be controlled by the flashlight
	for material in coral_shader_materials:
		if material:
			flashlight.add_shader(material)
			print("Added coral material to flashlight")
	
	# Connect flashlight signals
	flashlight.connect("toggled", _on_flashlight_toggled)
	print("Flashlight initialization complete")

# Add this function to initialize the god rays
func initialize_god_rays():
	var god_rays_scene = load("res://scenes/god_rays.tscn")
	god_rays = god_rays_scene.instantiate()
	
	# Create a CanvasLayer to hold the rays
	var rays_layer = CanvasLayer.new()
	rays_layer.layer = 5  # Adjust as needed
	add_child(rays_layer)
	rays_layer.add_child(god_rays)
