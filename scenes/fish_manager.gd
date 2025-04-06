extends Node2D

class_name FishManager

# Fish database - will be populated from fish_list
var fish_database = []
var active_fish = []
var current_depth = 0.0
var fish_scene = preload("res://scenes/fish.tscn")  # Assuming you saved the Fish scene

# Spawning parameters
@export var max_fish: int = 30
@export var spawn_interval: float = 2.0
@export var spawn_distance: float = 1000  # How far from player to spawn fish

# Node references
var player_node: Node2D
var spawn_timer: Timer

# Current depth zone tracking
var current_depth_zone = "" 

func _ready():
	# Initialize fish database
	load_fish_database()
	
	# Set up spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.autostart = true
	add_child(spawn_timer)
	spawn_timer.connect("timeout", spawn_fish)
	
	# Ensure at least one of each fish species in the current zone is spawned
	ensure_all_zone_species_spawned()
	
	# Find player node (assuming it exists in the scene)
	player_node = get_node_or_null("/root/Main/Player")
	if not player_node:
		print("Warning: Player node not found. Using default position.")

# Helper function to add fish entries with consistent parameter order
func add_fish_entry(entries_array, texture, name, scale, depth_range, sound, rarity, dangerous, swim_style, school_size, z_index_range=Vector2(-20, 10)):
	entries_array.append({
		"texture_path": texture,
		"fish_name": name,
		"scale_factor": scale,
		"depth_range": depth_range,
		"sound_path": sound,
		"rarity": rarity,
		"is_dangerous": dangerous,
		"swim_style": swim_style,
		"school_size": school_size,
		"z_index_range": z_index_range
	})

# Load fish database from configuration
func load_fish_database():
	# Create entries for all fish using the texture paths
	var fish_entries = []
	
	# Common small fish (shallow water)
	add_fish_entry(fish_entries, "res://assets/fish/fish1.png", "Blue Tang", 0.15, Vector2(0, 70), "res://assets/sounds/fish_bubble1.mp3", 1.0, false, "normal", 3, Vector2(-15, 15))
	add_fish_entry(fish_entries, "res://assets/fish/fish2.png", "Clownfish", 0.15, Vector2(0, 60), "res://assets/sounds/fish_bubble1.mp3", 1.0, false, "normal", 2, Vector2(-15, 15))
	add_fish_entry(fish_entries, "res://assets/fish/fish3.png", "Yellow Tang", 0.15, Vector2(0, 80), "res://assets/sounds/fish_bubble2.mp3", 0.9, false, "normal", 5, Vector2(-15, 15))
	add_fish_entry(fish_entries, "res://assets/fish/fish4.png", "Moorish Idol", 0.14, Vector2(10, 100), "res://assets/sounds/fish_bubble2.mp3", 0.8, false, "normal", 2, Vector2(-15, 15))
	add_fish_entry(fish_entries, "res://assets/fish/fish5.png", "Butterflyfish", 0.13, Vector2(0, 90), "res://assets/sounds/fish_bubble1.mp3", 0.9, false, "normal", 3, Vector2(-15, 15))
	
	# Mid-water fish
	add_fish_entry(fish_entries, "res://assets/fish/fish6.png", "Parrotfish", 0.20, Vector2(50, 150), "res://assets/sounds/fish_medium1.mp3", 0.8, false, "normal", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/fish7.png", "Angelfish", 0.18, Vector2(40, 140), "res://assets/sounds/fish_medium2.mp3", 0.7, false, "normal", 2, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/fish8.png", "Triggerfish", 0.22, Vector2(60, 170), "res://assets/sounds/fish_medium1.mp3", 0.6, false, "erratic", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/fish9.png", "Wrasse", 0.17, Vector2(30, 130), "res://assets/sounds/fish_medium2.mp3", 0.75, false, "normal", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/fish10.png", "Filefish", 0.19, Vector2(50, 160), "res://assets/sounds/fish_medium1.mp3", 0.65, false, "slow", 1, Vector2(0, 10))
	
	# Deeper fish
	add_fish_entry(fish_entries, "res://assets/fish/fish11.png", "Grouper", 0.25, Vector2(120, 250), "res://assets/sounds/fish_deep1.mp3", 0.5, false, "slow", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/fish12.png", "Barracuda", 0.28, Vector2(100, 300), "res://assets/sounds/fish_deep2.mp3", 0.4, true, "erratic", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/fish13.png", "Tuna", 0.3, Vector2(150, 400), "res://assets/sounds/fish_deep1.mp3", 0.45, false, "normal", 2, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/fish14.png", "Marlin", 0.35, Vector2(180, 350), "res://assets/sounds/fish_deep2.mp3", 0.35, true, "erratic", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/fish15.png", "Mahi-Mahi", 0.27, Vector2(120, 280), "res://assets/sounds/fish_deep1.mp3", 0.55, false, "normal", 1, Vector2(0, 10))
	
	# Special creatures
	add_fish_entry(fish_entries, "res://assets/fish/jellyfish1.png", "Jellyfish", 0.23, Vector2(0, 400), "res://assets/sounds/jellyfish.mp3", 0.6, true, "slow", 2, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/angler2.png", "Small Anglerfish", 0.25, Vector2(350, 600), "res://assets/sounds/angler.mp3", 0.3, true, "erratic", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/anglerfish.png", "Anglerfish", 0.35, Vector2(400, 800), "res://assets/sounds/angler.mp3", 0.2, true, "erratic", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/angler3.png", "Deep Anglerfish", 0.4, Vector2(600, 1000), "res://assets/sounds/angler.mp3", 0.15, true, "erratic", 1, Vector2(0, 10))
	
	# Eels
	add_fish_entry(fish_entries, "res://assets/fish/eel.png", "Moray Eel", 0.3, Vector2(150, 500), "res://assets/sounds/eel.mp3", 0.4, true, "slow", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/spottedeel.png", "Spotted Eel", 0.28, Vector2(200, 600), "res://assets/sounds/eel.mp3", 0.35, true, "slow", 1, Vector2(0, 10))
	
	# Larger creatures
	add_fish_entry(fish_entries, "res://assets/fish/ray1.png", "Manta Ray", 0.45, Vector2(200, 700), "res://assets/sounds/ray.mp3", 0.3, false, "slow", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/seahorse.png", "Seahorse", 0.2, Vector2(50, 200), "res://assets/sounds/seahorse.mp3", 0.5, false, "stationary", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/turtle.png", "Sea Turtle", 0.4, Vector2(100, 400), "res://assets/sounds/turtle.mp3", 0.35, false, "slow", 1, Vector2(0, 10))
	add_fish_entry(fish_entries, "res://assets/fish/hammerhead.png", "Hammerhead Shark", 0.5, Vector2(300, 800), "res://assets/sounds/shark.mp3", 0.25, true, "normal", 1, Vector2(0, 10))
	
	# Rare deep creatures
	add_fish_entry(fish_entries, "res://assets/fish/whale.png", "Whale", 2.0, Vector2(500, 1000), "res://assets/sounds/whale.mp3", 0.1, false, "slow", 1, Vector2(-20, -10))
	add_fish_entry(fish_entries, "res://assets/fish/whale2.png", "Humpback Whale", 2.0, Vector2(400, 900), "res://assets/sounds/whale.mp3", 0.08, false, "slow", 1, Vector2(-20, -10))
	
	fish_database = fish_entries
	print("Loaded " + str(fish_database.size()) + " fish types into database")

# Spawn a fish based on current depth
func spawn_fish():
	if active_fish.size() >= max_fish:
		return  # Don't spawn if we've reached the limit
	
	# Get fish that can appear at current depth
	var valid_fish = []
	for fish_data in fish_database:
		if current_depth >= fish_data.depth_range.x and current_depth <= fish_data.depth_range.y:
			# Apply rarity filter
			if randf() <= fish_data.rarity:
				valid_fish.append(fish_data)
	
	if valid_fish.size() == 0:
		return  # No valid fish for this depth
	
	# Select random fish from valid options
	var fish_data = valid_fish[randi() % valid_fish.size()]
	
	# Check if texture exists before spawning
	if !ResourceLoader.exists(fish_data.texture_path):
		print("Warning: Fish texture not found: " + fish_data.texture_path)
		return  # Skip this fish if texture is missing
	
	# Spawn a school of fish
	var school_size = fish_data.school_size
	
	# Position all fish based on screen boundaries, not depth or player position
	var screen_size = get_viewport_rect().size
	var spawn_side = randi() % 4  # 0=top, 1=right, 2=bottom, 3=left
	
	for i in range(school_size):
		var fish_instance = fish_scene.instantiate()
		if not fish_instance:
			print("Error instantiating fish scene")
			return
			
		# Apply fish data
		fish_instance.texture_path = fish_data.texture_path
		fish_instance.scale_factor = fish_data.scale_factor
		fish_instance.depth_range = fish_data.depth_range
		fish_instance.sound_path = fish_data.sound_path if "sound_path" in fish_data else ""
		fish_instance.rarity = fish_data.rarity if "rarity" in fish_data else 1.0
		fish_instance.is_dangerous = fish_data.is_dangerous if "is_dangerous" in fish_data else false
		fish_instance.swim_style = fish_data.swim_style if "swim_style" in fish_data else "normal"
		fish_instance.fish_name = fish_data.fish_name if "fish_name" in fish_data else "Fish"
		
		# Add variation within school
		var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50)) if i > 0 else Vector2.ZERO
		
		# Position based on screen edge, not depth
		match spawn_side:
			0:  # Top
				fish_instance.position = Vector2(randf_range(0, screen_size.x), -50) + offset
			1:  # Right
				fish_instance.position = Vector2(screen_size.x + 50, randf_range(0, screen_size.y)) + offset
			2:  # Bottom
				fish_instance.position = Vector2(randf_range(0, screen_size.x), screen_size.y + 50) + offset
			3:  # Left
				fish_instance.position = Vector2(-50, randf_range(0, screen_size.y)) + offset
		
		# Set z-index based on the fish's z_index_range
		var z_index_range = fish_data.z_index_range if "z_index_range" in fish_data else Vector2(-10, 10)
		fish_instance.z_index = randi_range(int(z_index_range.x), int(z_index_range.y))
		
		# Add to scene
		add_child(fish_instance)
		active_fish.append(fish_instance)
		
		# Set depth immediately
		fish_instance.set_depth(current_depth)  # Apply current depth right away
		fish_instance.update_sprite_orientation()  # Ensure orientation is set
		
		# For school behavior
		if i > 0 and active_fish.size() >= 2:
			# Make school fish follow similar paths
			var leader = active_fish[active_fish.size() - 2]
			if is_instance_valid(leader) and leader.velocity:
				fish_instance.velocity = leader.velocity.rotated(randf_range(-0.2, 0.2))
				fish_instance.velocity *= randf_range(0.9, 1.1)  # Slight speed variation
				# Explicitly update sprite orientation after setting velocity
				fish_instance.update_sprite_orientation()

# Update function with zone transition check
func update_depth(new_depth):
	# Check if we've entered a new depth zone
	var previous_zone = current_depth_zone
	current_depth_zone = get_depth_zone_name(new_depth)
	
	# If we've entered a new zone, spawn all species from this zone
	if previous_zone != current_depth_zone:
		print("Entered new depth zone: " + current_depth_zone)
		ensure_all_zone_species_spawned()
	
	# Update depth value
	current_depth = new_depth
	
	# Update all existing fish based on the new depth
	for fish in active_fish:
		if is_instance_valid(fish):
			fish.set_depth(current_depth)
			# Connect the ready_for_removal signal if not already connected
			if !fish.is_connected("ready_for_removal", _on_fish_ready_for_removal):
				fish.connect("ready_for_removal", _on_fish_ready_for_removal)
		else:
			active_fish.erase(fish)  # Remove invalid references

# Handle fish that's ready for removal
func _on_fish_ready_for_removal(fish):
	if fish in active_fish:
		active_fish.erase(fish)
		fish.queue_free()

# Clean up off-screen fish to manage performance
func _process(delta):
	var screen_rect = get_viewport_rect()
	screen_rect = screen_rect.grow(300)  # Allow margin outside screen
	
	var i = 0
	while i < active_fish.size():
		var fish = active_fish[i]
		if !is_instance_valid(fish):
			active_fish.remove_at(i)
			continue
			
		# Check if fish is way off screen AND outside its depth range
		# Only remove if both conditions are true
		if !screen_rect.has_point(fish.global_position) and \
		   !fish.is_in_valid_depth(current_depth) and \
		   fish.global_position.distance_to(screen_rect.get_center()) > 1000:
			fish.queue_free()
			active_fish.remove_at(i)
		else:
			i += 1 

# New function to ensure one of each species in the current zone is spawned
func ensure_all_zone_species_spawned():
	# Get all fish types that can exist at the current depth
	var fish_in_current_zone = []
	
	for fish_data in fish_database:
		if current_depth >= fish_data.depth_range.x and current_depth <= fish_data.depth_range.y:
			fish_in_current_zone.append(fish_data)
	
	print("Found " + str(fish_in_current_zone.size()) + " fish species in current depth zone")
	
	# Spawn one of each species
	for fish_data in fish_in_current_zone:
		# Skip if we've reached max fish count
		if active_fish.size() >= max_fish:
			print("Warning: Max fish limit reached while ensuring zone species")
			break
			
		# Check if texture exists before spawning
		if !ResourceLoader.exists(fish_data.texture_path):
			print("Warning: Fish texture not found: " + fish_data.texture_path)
			continue
		
		# Spawn just one of this species (not the whole school)
		var fish_instance = fish_scene.instantiate()
		if not fish_instance:
			print("Error instantiating fish scene")
			continue
			
		# Apply fish data
		fish_instance.texture_path = fish_data.texture_path
		fish_instance.scale_factor = fish_data.scale_factor
		fish_instance.depth_range = fish_data.depth_range
		fish_instance.sound_path = fish_data.sound_path if "sound_path" in fish_data else ""
		fish_instance.rarity = fish_data.rarity if "rarity" in fish_data else 1.0
		fish_instance.is_dangerous = fish_data.is_dangerous if "is_dangerous" in fish_data else false
		fish_instance.swim_style = fish_data.swim_style if "swim_style" in fish_data else "normal"
		fish_instance.fish_name = fish_data.fish_name if "fish_name" in fish_data else "Fish"
		
		# Position in a visible but random position on screen
		var screen_size = get_viewport_rect().size
		var margin = 100
		
		fish_instance.position = Vector2(
			randf_range(margin, screen_size.x - margin),
			randf_range(margin, screen_size.y - margin)
		)
		
		# Set z-index based on the fish's z_index_range
		var z_index_range = fish_data.z_index_range if "z_index_range" in fish_data else Vector2(-10, 10)
		fish_instance.z_index = randi_range(int(z_index_range.x), int(z_index_range.y))
		
		# Add to scene
		add_child(fish_instance)
		active_fish.append(fish_instance)
		
		# Set depth immediately
		fish_instance.set_depth(current_depth)
		fish_instance.update_sprite_orientation()
		
		print("Spawned " + fish_instance.fish_name + " for zone completion") 

# Helper function to determine the depth zone name based on depth
func get_depth_zone_name(depth):
	if depth < 50:
		return "shallow"
	elif depth < 150:
		return "mid"
	elif depth < 300:
		return "deep"
	else:
		return "abyss"
