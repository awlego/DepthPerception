extends Node2D

# Parallax layers
var parallax_layers = []  # Will hold our 9 layers instead of 5
var layer_speeds = [0.92, 0.93, 0.94, 0.95, 0.96, 0.97, 0.98, 0.99, 1.0]  # Far -> close (multipliers)
var layer_scale = [0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50]  # Smaller scales for farther layers
var base_density = 2
var layer_density = []  # Will be populated in _ready()
var layer_z_indices = [-40, -35, -30, -25, -20, -15, -10, -5, 0]  # Far to close layers

# Coral wall properties
var coral_textures = []  # Will hold all coral textures
var segment_height = 1024  # Height of each segment in pixels
var num_visible_segments = 3  # How many segments to keep active at once

var rock_textures = []

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
	# Initialize layer density based on scale
	layer_density = []
	for s in layer_scale:
		layer_density.append(round(1/s**2) * base_density)
	
	# Load all coral textures
	preload_coral_textures()
	
	# Load all rock textures
	preload_rock_textures()
	
	# Create our nine parallax layers
	setup_parallax_layers()
	
	# Generate initial segments for each layer
	for layer_index in range(parallax_layers.size()):
		for i in range(num_visible_segments):
			generate_coral_segment(layer_index, i * segment_height)
	
	# Debug print coral count per layer
	print_coral_counts()

# Preload all coral textures
func preload_coral_textures():
	# You'll need to create/provide these coral textures
	coral_textures = [
		preload("res://assets/background-objs/coral1.png"),
		preload("res://assets/background-objs/coral2.png"),
		preload("res://assets/background-objs/coral3.png"),
		preload("res://assets/background-objs/coral4.png"),
		preload("res://assets/background-objs/coral5.png"),
		preload("res://assets/background-objs/coral6.png"),
		preload("res://assets/background-objs/coral7.png"),
		preload("res://assets/background-objs/coral8.png"),
		preload("res://assets/background-objs/coral9.png"),
		preload("res://assets/background-objs/coral10.png"),
		preload("res://assets/background-objs/coral11.png"),
		preload("res://assets/background-objs/coral12.png"),
		preload("res://assets/background-objs/coral13.png"),
		preload("res://assets/background-objs/coral14.png"),
		preload("res://assets/background-objs/kelp1.png"),
		preload("res://assets/background-objs/kelp2.png"),
		# Add more coral textures as needed
	]
	
	# Create shader materials for each layer
	create_layer_shaders()

func preload_rock_textures():
	rock_textures = [
		preload("res://assets/background-objs/rock2.png"),
		preload("res://assets/background-objs/rock3.png"),
		preload("res://assets/background-objs/rock4.png"),
		preload("res://assets/background-objs/rock5.png"),
		preload("res://assets/background-objs/rock6.png"),
	]

# Setup the parallax layers
func setup_parallax_layers():
	# Create 9 layers - farthest to closest
	for i in range(9):  # Changed from 5 to 9
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
	var screen_start = viewport_width * 0.35  # Start at 35% of screen width instead of 50%
	
	# Divide the right portion of the screen into equal bands for each layer
	var available_width = viewport_width - screen_start
	var band_width = available_width / parallax_layers.size()
	var band_start = screen_start + (layer_index * band_width)
	var band_end = band_start + band_width
	
	# Scale density based on layer
	var segment_density = layer["density"]
	
	for i in range(segment_density):
		var coral = Sprite2D.new()
		
		# Determine if this will be a rock or coral
		var is_rock = layer_index <= 2 and rock_textures.size() > 0 and randf() > 0.4
		
		# Select texture based on layer - rocks for far layers (0, 1, 2), coral for near layers (3, 4)
		var texture_index
		if is_rock:  # 60% chance of rocks in far layers
			texture_index = randi() % rock_textures.size()
			coral.texture = rock_textures[texture_index]
			# Set rocks to be behind other elements in their layer
			coral.z_index = -5
		else:
			texture_index = randi() % coral_textures.size()
			coral.texture = coral_textures[texture_index]
			coral.z_index = 0  # Default z_index for corals
		
		# Random position within the segment - LAYER-SPECIFIC BAND
		coral.position = Vector2(
			randf_range(band_start, band_end),  # Only spawn in this layer's band
			randf_range(0, segment_height)
		)
		
		# Scale based on layer (smaller for far objects)
		var base_scale = layer["scale"]
		var variation = randf_range(0.8, 1.2)  # Some variation within layer
		var scale_factor = base_scale * variation
		
		# Make rocks twice as big
		if is_rock:
			scale_factor *= 2.0
			
		coral.scale = Vector2(scale_factor, scale_factor)
		
		# Opacity based on layer (more transparent for far objects)
		coral.modulate.a = 0.7 + (layer_index * 0.15)  # 0.7, 0.85, 1.0
		
		# Random flip for more variety
		if randf() > 0.5:
			coral.flip_h = true
		
		if layer_index < layer_materials.size() and layer_materials[layer_index]:
			# Create a unique copy of the material for this coral
			var unique_material = layer_materials[layer_index].duplicate()
			coral.material = unique_material
			
			# Initial setup of shader parameters for this specific coral
			unique_material.set_shader_parameter("sprite_world_position", coral.global_position)
			unique_material.set_shader_parameter("sprite_size", coral.texture.get_size() * coral.scale)
			unique_material.set_shader_parameter("screen_size", get_viewport_rect().size)
			
			# print("Applied unique material to coral in layer", layer_index)
		
		# Add to segment
		segment.add_child(coral)
		update_coral_shader_params(coral)
	
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
			
			# After moving the segment, update all coral shader params
			for coral in segment.get_children():
				if coral is Sprite2D and coral.material:
					update_coral_shader_params(coral)
			
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
	var screen_start = viewport_width * 0.35  # Start at 35% of screen width instead of 50%
	
	# Divide the right portion of the screen into equal bands for each layer
	var available_width = viewport_width - screen_start
	var band_width = available_width / parallax_layers.size()
	var band_start = screen_start + (layer_index * band_width)
	var band_end = band_start + band_width
	
	# Scale density based on layer
	var segment_density = layer["density"]
	
	for i in range(segment_density):
		var coral = Sprite2D.new()
		
		# Determine if this will be a rock or coral
		var is_rock = layer_index <= 2 and rock_textures.size() > 0 and randf() > 0.4
		
		# Select texture based on layer - rocks for far layers (0, 1, 2), coral for near layers (3, 4)
		var texture_index
		if is_rock:  # 60% chance of rocks in far layers
			texture_index = randi() % rock_textures.size()
			coral.texture = rock_textures[texture_index]
			# Set rocks to be behind other elements in their layer
			coral.z_index = -5
		else:
			texture_index = randi() % coral_textures.size()
			coral.texture = coral_textures[texture_index]
			coral.z_index = 0  # Default z_index for corals
		
		# Random position within the segment - LAYER-SPECIFIC BAND
		coral.position = Vector2(
			randf_range(band_start, band_end),  # Only spawn in this layer's band
			randf_range(0, segment_height)
		)
		
		# Scale based on layer (smaller for far objects)
		var base_scale = layer["scale"]
		var variation = randf_range(0.8, 1.2)  # Some variation within layer
		var scale_factor = base_scale * variation
		
		# Make rocks twice as big
		if is_rock:
			scale_factor *= 2.0
			
		coral.scale = Vector2(scale_factor, scale_factor)
		
		# Opacity based on layer (more transparent for far objects)
		coral.modulate.a = 0.7 + (layer_index * 0.15)  # 0.7, 0.85, 1.0
		
		# Random rotation for variety
		coral.rotation_degrees = randf_range(-10, 10)
		
		# Random flip
		if randf() > 0.5:
			coral.flip_h = true
		
		if layer_index < layer_materials.size() and layer_materials[layer_index]:
			# Create a unique copy of the material for this coral
			var unique_material = layer_materials[layer_index].duplicate()
			coral.material = unique_material
			
			# Initial setup of shader parameters for this specific coral
			unique_material.set_shader_parameter("sprite_world_position", coral.global_position)
			unique_material.set_shader_parameter("sprite_size", coral.texture.get_size() * coral.scale)
			unique_material.set_shader_parameter("screen_size", get_viewport_rect().size)
			
			# print("Applied unique material to regenerated coral in layer", layer_index)
		
		segment.add_child(coral)
		update_coral_shader_params(coral)

# Called every frame
func _process(delta):
	# We no longer need this since we update after movement
	# for layer_index in range(parallax_layers.size()):
	#     var layer = parallax_layers[layer_index]
	#     for segment in layer["segments"]:
	#         for coral in segment.get_children():
	#             if coral is Sprite2D:
	#                 update_coral_shader_params(coral, layer_index)
	
	# In a real implementation, main.gd would call update_depth()
	# But for testing we can uncomment this:
	# update_depth(current_depth + delta)
	pass

# Replace your create_layer_shaders function
func create_layer_shaders():
	# Try to load the shader
	var shader_path = "res://assets/shaders/distance_shader.gdshader"
	
	# Check if the shader exists
	if ResourceLoader.exists(shader_path):
		coral_shader = load(shader_path)
		print("Shader loaded successfully")
	else:
		print("WARNING: Shader not found at path: " + shader_path)
		return  # Exit the function if shader isn't found
	
	# Create shader materials for each layer with different parameter sets
	for i in range(9):  # Changed from 5 to 9
		var material = ShaderMaterial.new()
		material.shader = coral_shader
		
		# Configure parameters based on layer with manual distance settings
		if i == 0:  # Furthest layer
			material.set_shader_parameter("distance", 150.0)
			material.set_shader_parameter("wave_strength", 0.001)
			material.set_shader_parameter("wave_speed", 0.2)
		elif i == 1:
			material.set_shader_parameter("distance", 120.0)
			material.set_shader_parameter("wave_strength", 0.0012)
			material.set_shader_parameter("wave_speed", 0.25)
		elif i == 2:
			material.set_shader_parameter("distance", 100.0)
			material.set_shader_parameter("wave_strength", 0.0015)
			material.set_shader_parameter("wave_speed", 0.3)
		elif i == 3:
			material.set_shader_parameter("distance", 50.0)
			material.set_shader_parameter("wave_strength", 0.0018)
			material.set_shader_parameter("wave_speed", 0.35)
		elif i == 4:  # Mid layer
			material.set_shader_parameter("distance", 15.0)
			material.set_shader_parameter("wave_strength", 0.002)
			material.set_shader_parameter("wave_speed", 0.4)
		elif i == 5:
			material.set_shader_parameter("distance", 10.0)
			material.set_shader_parameter("wave_strength", 0.0025)
			material.set_shader_parameter("wave_speed", 0.5)
		elif i == 6:
			material.set_shader_parameter("distance", 6.0)
			material.set_shader_parameter("wave_strength", 0.003)
			material.set_shader_parameter("wave_speed", 0.6)
		elif i == 7:
			material.set_shader_parameter("distance", 3.0)
			material.set_shader_parameter("wave_strength", 0.0035)
			material.set_shader_parameter("wave_speed", 0.7)
		else:  # Closest layer (i == 8)
			material.set_shader_parameter("distance", 0.0)
			material.set_shader_parameter("wave_strength", 0.004)
			material.set_shader_parameter("wave_speed", 0.8)
		
		# Add a unique wave offset for each layer to prevent synchronized movement
		material.set_shader_parameter("wave_offset", randf() * 10.0)
		
		# Set initial flashlight parameters (disabled by default)
		material.set_shader_parameter("flashlight_on", false)
		material.set_shader_parameter("light_position", Vector2(0.5, 0.5))
		material.set_shader_parameter("light_radius", 0.3)
		material.set_shader_parameter("light_intensity", 1.5)
		material.set_shader_parameter("light_falloff", 3.0)
		
		# Add these critical position parameters
		material.set_shader_parameter("sprite_world_position", Vector2(0, 0))
		material.set_shader_parameter("sprite_size", Vector2(0, 0))
		material.set_shader_parameter("screen_size", get_viewport_rect().size)
		
		layer_materials.append(material)

# Add this function to update flashlight parameters
func update_flashlight(is_on, position=Vector2(0.5, 0.5), radius=0.3, intensity=1.5, falloff=3.0):
	# Update flashlight parameters on all individual coral materials
	for layer_index in range(parallax_layers.size()):
		var layer = parallax_layers[layer_index]
		
		for segment in layer["segments"]:
			for coral in segment.get_children():
				if coral is Sprite2D and coral.material:
					coral.material.set_shader_parameter("flashlight_on", is_on)
					
					# Convert position to UV coordinates (0-1 range)
					var viewport_size = get_viewport_rect().size
					var light_pos_uv = Vector2(
						position.x / viewport_size.x,
						position.y / viewport_size.y
					)
					
					coral.material.set_shader_parameter("light_position", light_pos_uv)
					coral.material.set_shader_parameter("light_radius", radius)
					coral.material.set_shader_parameter("light_intensity", intensity)
					coral.material.set_shader_parameter("light_falloff", falloff)
	
	# This can stay if you also need to update a separate flashlight node
	if get_node_or_null("/root/Main/Flashlight"):
		var flashlight = get_node("/root/Main/Flashlight")
		flashlight.toggle(is_on)
		flashlight.update_position(position, get_viewport_rect().size)

# Add a method to get all shader materials
func get_shader_materials():
	return layer_materials

# Optional: Add a convenience method to add a flashlight controller
func connect_to_flashlight(flashlight_node):
	for material in layer_materials:
		flashlight_node.add_shader(material)

# Helper function to update shader position parameters for a coral sprite
func update_coral_shader_params(coral: Sprite2D):
	if coral.material:
		# Now we're using the coral's own unique material instance
		coral.material.set_shader_parameter("sprite_world_position", coral.global_position)
		coral.material.set_shader_parameter("sprite_size", coral.texture.get_size() * coral.scale)
		coral.material.set_shader_parameter("screen_size", get_viewport_rect().size)

# Add this new function to count and print coral per layer
func print_coral_counts():
	print("=== Coral Count Per Layer ===")
	for layer_index in range(parallax_layers.size()):
		var layer = parallax_layers[layer_index]
		var coral_count = 0
		
		# Count all coral in this layer's segments
		for segment in layer["segments"]:
			coral_count += segment.get_child_count()
		
		print("Layer ", layer_index, " (scale: ", layer_scale[layer_index], 
			", target density: ", layer_density[layer_index], 
			"): ", coral_count, " coral")
	print("===========================")
