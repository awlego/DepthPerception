extends Area2D

class_name Fish  # Add class_name to make it easier to reference

# Basic fish properties
@export var speed_range: Vector2 = Vector2(50, 150)  # Min/max speed range
@export var direction_change_time: float = 2.0  # Time in seconds before changing direction
@export var texture_path: String = ""

# Enhanced properties
@export var scale_factor: float = 0.2  # Scale of the fish sprite
@export var depth_range: Vector2 = Vector2(0, 1000)  # Min/max depth this fish can appear at
@export var sound_path: String = ""  # Path to sound effect
@export var rarity: float = 1.0  # How rare is this fish (1.0 = common, 0.1 = rare)
@export var is_dangerous: bool = false  # Is this fish dangerous to the player?
@export var swim_style: String = "normal"  # "normal", "erratic", "slow", "stationary"
@export var school_size: int = 1  # How many fish in a school (1 = solo)

# Runtime variables
var velocity: Vector2
var timer: Timer
var sprite: Sprite2D
var audio_player: AudioStreamPlayer2D
var current_depth: float = 0.0
var is_active: bool = true
var fish_name: String = "Fish"

# Called when the node enters the scene tree
func _ready():
	# Add to fish group for detection
	add_to_group("fish")
	
	# Set up collision first
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20 * scale_factor
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Initial velocity based on swim style - MOVE THIS BEFORE SPRITE SETUP
	setup_swim_behavior()
	
	# Set up sprite AFTER velocity is determined
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	if texture_path and texture_path != "":
		sprite.texture = load(texture_path)
		sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(sprite)
	
	# Explicitly update orientation immediately
	update_sprite_orientation()
	
	# Set up sound
	if sound_path and sound_path != "":
		audio_player = AudioStreamPlayer2D.new()
		audio_player.name = "AudioPlayer"
		
		# Check if sound file exists before trying to load it
		if ResourceLoader.exists(sound_path):
			var sound = load(sound_path)
			audio_player.stream = sound
			audio_player.max_distance = 500
			audio_player.attenuation = 2.0
			add_child(audio_player)
		# leaving commented out to not have a bunch of warnings
		# else:
			# Sound file doesn't exist, print a warning but continue without error
			# print("Warning: Sound file not found: " + sound_path + " for fish: " + fish_name)
			# Don't add the audio player since there's no sound to play
	
	# Create timer for direction change
	timer = Timer.new()
	timer.wait_time = randf_range(direction_change_time * 0.5, direction_change_time * 1.5)
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.connect("timeout", change_direction)
	
	# Connect signal for when player enters detection area
	connect("area_entered", _on_area_entered)
	connect("body_entered", _on_body_entered)

# Initialize fish behavior based on swim style
func setup_swim_behavior():
	match swim_style:
		"normal":
			speed_range = Vector2(50, 150)
			direction_change_time = 2.0
		"erratic":
			speed_range = Vector2(100, 200)
			direction_change_time = 0.8
		"slow":
			speed_range = Vector2(20, 60)
			direction_change_time = 4.0
		"stationary":
			speed_range = Vector2(5, 15)
			direction_change_time = 6.0
	
	randomize_velocity()

# Change fish direction randomly
func change_direction():
	# Different behavior based on swim style
	match swim_style:
		"normal":
			randomize_velocity()
		"erratic":
			# More extreme direction changes
			velocity = Vector2(
				randf_range(-1.5, 1.5),
				randf_range(-1.5, 1.5)
			).normalized() * randf_range(speed_range.x, speed_range.y)
		"slow", "stationary":
			# Gentler direction changes
			var current_dir = velocity.normalized()
			var angle_change = randf_range(-PI/4, PI/4)
			var new_dir = current_dir.rotated(angle_change)
			velocity = new_dir * randf_range(speed_range.x, speed_range.y)
	
	# Update sprite orientation
	update_sprite_orientation()

# Randomize the velocity vector
func randomize_velocity():
	velocity = Vector2(
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized() * randf_range(speed_range.x, speed_range.y)
	
	update_sprite_orientation()

# Update sprite based on direction
func update_sprite_orientation():
	if sprite and is_instance_valid(sprite):
		# Force a single frame delay to ensure proper rendering
		await get_tree().process_frame
		
		# Make sure we only have one sprite orientation
		if velocity.x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
		
		# Force update the sprite's transform
		sprite.force_update_transform()

# Play sound with optional cooldown
func play_sound():
	if audio_player and is_instance_valid(audio_player) and audio_player.stream:
		if !audio_player.playing:
			audio_player.pitch_scale = randf_range(0.9, 1.1)  # Small pitch variation
			audio_player.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !is_active:
		return
	
	# Move fish
	position += velocity * delta
	
	# Check if fish is off screen
	var screen_rect = get_viewport_rect()
	var is_offscreen = !screen_rect.has_point(position)
	
	# If fish is offscreen and not in valid depth range, signal for removal
	if is_offscreen and !is_in_valid_depth(current_depth):
		# Tell parent (fish manager) this fish can be removed
		emit_signal("ready_for_removal", self)
		# Disable processing but keep in scene until manager removes it
		set_process(false)
		return
	
	# Handle screen boundaries - bounce only if in valid depth range
	var bounce = false
	
	if is_in_valid_depth(current_depth):
		# Normal bounce behavior for fish in valid depth
		if position.x < 0:
			position.x = 0
			velocity.x = abs(velocity.x)
			bounce = true
		elif position.x > screen_rect.size.x:
			position.x = screen_rect.size.x
			velocity.x = -abs(velocity.x)
			bounce = true
			
		if position.y < 0:
			position.y = 0
			velocity.y = abs(velocity.y)
			bounce = true
		elif position.y > screen_rect.size.y:
			position.y = screen_rect.size.y
			velocity.y = -abs(velocity.y)
			bounce = true
	else:
		# Out of depth range: don't bounce, keep heading offscreen
		pass
	
	# Update sprite orientation if bounced
	if bounce:
		update_sprite_orientation()
		if randf() < 0.3:  # 30% chance to play sound when bouncing off walls
			play_sound()

# Set the fish's depth - decides visibility based on valid depth range
func set_depth(depth):
	current_depth = depth
	
	# Check if fish is in valid depth range
	var in_valid_depth = is_in_valid_depth(depth)
	
	if !in_valid_depth and is_active:
		# If fish was active but now out of range, make it swim offscreen
		swim_offscreen()
	elif in_valid_depth and !is_active:
		# Fish is back in valid depth range, make it active again
		is_active = true
		visible = true
		set_process(true)

# Check if fish is in valid depth range
func is_in_valid_depth(depth):
	return depth >= depth_range.x and depth <= depth_range.y

# Interaction handlers
func _on_area_entered(area):
	if area.is_in_group("player"):
		play_sound()
		# Fish reacts to player (swim away, attack, etc.)
		if is_dangerous:
			# Attack behavior
			velocity = (area.global_position - global_position).normalized() * speed_range.y
		else:
			# Swim away behavior
			velocity = (global_position - area.global_position).normalized() * speed_range.y
		
		update_sprite_orientation()

func _on_body_entered(body):
	if body.is_in_group("player"):
		play_sound()
		# Similar behavior as area_entered
		if is_dangerous:
			velocity = (body.global_position - global_position).normalized() * speed_range.y
		else:
			velocity = (global_position - body.global_position).normalized() * speed_range.y
		
		update_sprite_orientation() 

# Make the fish swim toward the nearest screen edge
func swim_offscreen():
	# Don't change status yet - just change direction
	
	# Determine nearest screen edge
	var screen_size = get_viewport_rect().size
	var screen_center = screen_size / 2
	var direction_to_center = screen_center - position
	
	# Swim away from center (toward nearest edge)
	velocity = -direction_to_center.normalized() * speed_range.y * 1.5  # Faster escape speed
	
	# Update sprite orientation
	update_sprite_orientation()
	
	# Set a flag to indicate we're trying to leave
	is_active = true  # Keep active but trying to leave
	visible = true
	set_process(true) 

# Add at the top of the file after class definition
signal ready_for_removal(fish) 
