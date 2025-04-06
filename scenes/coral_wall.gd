extends Node2D

# Parallax layers
var parallax_layers = []  # Will hold our 3 layers
var layer_speeds = [0.8, 0.9, 1.0]  # Far, mid, close (multipliers)
var layer_scale = [0.25, 0.35, 0.5]  # Smaller scales for all layers (farther layers much smaller)
var layer_density = [1000, 100, 50]
var layer_z_indices = [-10, -5, 0]  # Far to close layers

# Coral wall properties
var coral_textures = []  # Will hold all coral textures
var segment_height = 1024  # Height of each segment in pixels
var num_visible_segments = 3  # How many segments to keep active at once

# Parallax properties
var scroll_speed = 100.0  # Base scroll speed
var current_depth = 0.0  # Will be updated from main
var last_segment_depth = 0.0  # Tracks when we last generated a segment

# Coral density and variation
var depth_zones = {
	"shallow": {"max_depth": 50.0, "textures": ["coral1", "coral2", "coral3"]},
	"mid": {"max_depth": 150.0, "textures": ["coral2", "coral3", "coral4"]},
	"deep": {"max_depth": 300.0, "textures": ["coral1", "coral2", "coral3"]},
	"abyss": {"max_depth": 1000.0, "textures": ["coral2", "coral2", "coral4"]}
}

# Add these variables at the top of your script
var coral_shader: Shader
var layer_materials = []

# Called when the node enters the scene tree for the first time
func _ready():
	# Load all coral textures
	preload_coral_textures()
	
	# Create our three parallax layers
	setup_parallax_layers()
	
	# Generate initial segments for each layer
	for layer_index in range(parallax_layers.size()):
		for i in range(num_visible_segments):
			generate_coral_segment(layer_index, i * segment_height)

# Preload all coral textures
func preload_coral_textures():
	# You'll need to create/provide these coral textures
	coral_textures = [
		preload("res://assets/background-objs/coral1.png"),
		preload("res://assets/background-objs/coral2.png"),
		preload("res://assets/background-objs/coral3.png"),
		preload("res://assets/background-objs/coral4.png"),
		# Add more coral textures as needed
	]

# Setup the three parallax layers
func setup_parallax_layers():
	# Create 3 layers - far, mid, close
	for i in range(3):
		var layer = {
			"node": Node2D.new(),
			"segments": [],
			"speed": layer_speeds[i],
			"scale": layer_scale[i],
			"density": layer_density[i]
		}
		
		layer["node"].name = "ParallaxLayer_" + str(i)
		layer["node"].z_index = layer_z_indices[i]
		add_child(layer["node"])
		
		parallax_layers.append(layer)

# Generate a new segment of coral for a specific layer
func generate_coral_segment(layer_index, vertical_position):
	var layer = parallax_layers[layer_index]
	
	# Create a Y-sorted node instead of a regular Node2D
	var segment = Node2D.new()
	segment.y_sort_enabled = true  # Enable Y-sorting within this segment
	
	segment.position.y = vertical_position
	segment.name = "CoralSegment_" + str(vertical_position)
	layer["node"].add_child(segment)
	
	# Determine which corals to use based on current depth
	var current_zone = get_depth_zone(current_depth)
	
	# Calculate different spawn regions for each layer
	var viewport_width = get_viewport_rect().size.x
	var screen_mid = viewport_width / 2
	
	# Define the minimum X position for each layer
	# Layer 0 (farthest): starts at 50% of screen width (screen_mid)
	# Layer 1 (middle): starts at 62.5% of screen width (screen_mid + screen_mid/4)
	# Layer 2 (closest): starts at 75% of screen width (screen_mid + screen_mid/2)
	var min_x_pos = screen_mid
	if layer_index == 1:
		min_x_pos = screen_mid + (screen_mid / 4)  # 62.5% of screen width
	elif layer_index == 2:
		min_x_pos = screen_mid + (screen_mid / 2)  # 75% of screen width
	
	# Scale density based on layer
	var segment_density = layer["density"]
	
	for i in range(segment_density):
		var coral = Sprite2D.new()
		
		# Select random coral texture appropriate for the depth
		var texture_index = randi() % coral_textures.size()
		coral.texture = coral_textures[texture_index]
		
		# Random position within the segment - LAYER-SPECIFIC RIGHT SECTION
		coral.position = Vector2(
			randf_range(min_x_pos, viewport_width),  # Only spawn in appropriate right section
			randf_range(0, segment_height)
		)
		
		# Scale based on layer (smaller for far objects)
		var base_scale = layer["scale"]
		var variation = randf_range(0.8, 1.2)  # Some variation within layer
		var scale_factor = base_scale * variation
		coral.scale = Vector2(scale_factor, scale_factor)
		
		# Opacity based on layer (more transparent for far objects)
		coral.modulate.a = 0.7 + (layer_index * 0.15)  # 0.7, 0.85, 1.0
		
		# Random flip for more variety
		if randf() > 0.5:
			coral.flip_h = true
		
		# Add to segment
		segment.add_child(coral)
	
	# Track this segment in the layer
	layer["segments"].append(segment)

# Determine which depth zone we're in
func get_depth_zone(depth):
	var zone = "shallow"  # Default
	for z in depth_zones:
		if depth <= depth_zones[z]["max_depth"]:
			zone = z
			break
	return zone

# Update all layers based on current depth
func update_depth(new_depth):
	# Calculate movement since last frame
	var depth_change = new_depth - current_depth
	current_depth = new_depth
	
	# Update each layer
	for layer_index in range(parallax_layers.size()):
		var layer = parallax_layers[layer_index]
		
		# Calculate movement speed for this layer (farther = slower)
		var layer_move_amount = depth_change * scroll_speed * layer["speed"]
		
		# Move all segments in this layer
		for segment in layer["segments"]:
			segment.position.y -= layer_move_amount
			
			# If this segment has moved off screen, reposition it
			if segment.position.y < -segment_height:
				# Find the lowest segment in this layer
				var lowest_y = -segment_height
				for s in layer["segments"]:
					if s.position.y > lowest_y:
						lowest_y = s.position.y
				
				# Position this segment below the lowest one
				segment.position.y = lowest_y + segment_height
				
				# Regenerate this segment with new coral appropriate for the depth
				regenerate_segment_contents(layer_index, segment)

# Regenerate the contents of a segment with new coral
func regenerate_segment_contents(layer_index, segment):
	var layer = parallax_layers[layer_index]
	
	# Remove all existing coral from this segment
	for child in segment.get_children():
		child.queue_free()
	
	# Calculate different spawn regions for each layer
	var viewport_width = get_viewport_rect().size.x
	var screen_mid = viewport_width / 2
	
	# Define the minimum X position for each layer
	# Layer 0 (farthest): starts at 50% of screen width (screen_mid)
	# Layer 1 (middle): starts at 62.5% of screen width (screen_mid + screen_mid/4)
	# Layer 2 (closest): starts at 75% of screen width (screen_mid + screen_mid/2)
	var min_x_pos = screen_mid
	if layer_index == 1:
		min_x_pos = screen_mid + (screen_mid / 4)  # 62.5% of screen width
	elif layer_index == 2:
		min_x_pos = screen_mid + (screen_mid / 2)  # 75% of screen width
	
	# Scale density based on layer
	var segment_density = layer["density"]
	
	for i in range(segment_density):
		var coral = Sprite2D.new()
		
		# Select appropriate coral texture for current depth
		var texture_index = randi() % coral_textures.size()
		coral.texture = coral_textures[texture_index]
		
		# Random position within the segment - LAYER-SPECIFIC RIGHT SECTION
		coral.position = Vector2(
			randf_range(min_x_pos, viewport_width),  # Only spawn in appropriate right section
			randf_range(0, segment_height)
		)
		
		# Scale based on layer (smaller for far objects)
		var base_scale = layer["scale"]
		var variation = randf_range(0.8, 1.2)  # Some variation within layer
		var scale_factor = base_scale * variation
		coral.scale = Vector2(scale_factor, scale_factor)
		
		# Opacity based on layer (more transparent for far objects)
		coral.modulate.a = 0.7 + (layer_index * 0.15)  # 0.7, 0.85, 1.0
		
		# Random rotation for variety
		coral.rotation_degrees = randf_range(-10, 10)
		
		# Random flip
		if randf() > 0.5:
			coral.flip_h = true
		
		segment.add_child(coral)

# Called every frame
func _process(delta):
	# In a real implementation, main.gd would call update_depth()
	# But for testing we can uncomment this:
	# update_depth(current_depth + delta)
	pass

# Replace your create_layer_shaders function with this
func create_layer_shaders():
	# Load a single shader
	coral_shader = load("res://assets/shaders/coral_underwater.gdshader")
	
	# Create shader materials for each layer with different parameter sets
	for i in range(3):
		var material = ShaderMaterial.new()
		material.shader = coral_shader
		
		# Configure parameters based on layer
		if i == 0:  # Far layer
			material.set_shader_parameter("distance", 100)
			material.set_shader_parameter("blue_tint", 0.4)
			material.set_shader_parameter("wave_strength", 0.002)
			material.set_shader_parameter("wave_speed", 0.3)
			material.set_shader_parameter("brightness", 0.9)
			material.set_shader_parameter("contrast", 0.9)
		elif i == 1:  # Mid layer
			material.set_shader_parameter("distance", 40)
			material.set_shader_parameter("blue_tint", 0.2)
			material.set_shader_parameter("wave_strength", 0.003)
			material.set_shader_parameter("wave_speed", 0.5)
			material.set_shader_parameter("brightness", 1.0)
			material.set_shader_parameter("contrast", 1.0)
		else:  # Close layer
			material.set_shader_parameter("distance", 5)
			material.set_shader_parameter("blue_tint", 0.1)
			material.set_shader_parameter("wave_strength", 0.004)
			material.set_shader_parameter("wave_speed", 0.7)
			material.set_shader_parameter("brightness", 1.1)
			material.set_shader_parameter("contrast", 1.1)
		
		# Add a unique wave offset for each layer to prevent synchronized movement
		material.set_shader_parameter("wave_offset", randf() * 10.0)
		
		layer_materials.append(material)
