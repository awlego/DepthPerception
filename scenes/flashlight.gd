# flashlight.gd
extends Node

signal toggled(is_on)

# Flashlight parameters
var shaders = [] # Will hold all shaders that need flashlight updates
var flashlight_on: bool = false

# Default values
const DEFAULT_RADIUS := 0.17
const DEFAULT_INTENSITY := 1.0
const DEFAULT_FALLOFF := 1.5
const MIN_RADIUS := 0.1
const MAX_RADIUS := 0.5
const MIN_INTENSITY := 0.0
const MAX_INTENSITY := 1.0
const MIN_FALLOFF := 1.0
const MAX_FALLOFF := 5.0

# Initialize with a single shader (for backwards compatibility)
func initialize(material: ShaderMaterial):
	add_shader(material)
	set_parameters()

# Add a shader to be controlled by this flashlight
func add_shader(material: ShaderMaterial):
	if material and !shaders.has(material):
		shaders.append(material)
		# Apply current settings to the new shader
		set_shader_parameters(material)
		
# Set initial flashlight parameters
func set_parameters():
	for shader in shaders:
		set_shader_parameters(shader)

# Apply parameters to a specific shader
func set_shader_parameters(shader):
	if shader:
		shader.set_shader_parameter("light_radius", DEFAULT_RADIUS)
		shader.set_shader_parameter("light_intensity", DEFAULT_INTENSITY)
		shader.set_shader_parameter("light_falloff", DEFAULT_FALLOFF)
		shader.set_shader_parameter("flashlight_on", flashlight_on)

# Toggle the flashlight on/off
func toggle(force_state = null):
	if force_state != null:
		flashlight_on = force_state
	else:
		flashlight_on = !flashlight_on
	
	for shader in shaders:
		shader.set_shader_parameter("flashlight_on", flashlight_on)
	
	print("Flashlight", " ON" if flashlight_on else " OFF")
	emit_signal("toggled", flashlight_on)

# Update the light position based on screen coordinates
func update_position(screen_pos: Vector2, viewport_size: Vector2):
	var light_pos = Vector2(
		screen_pos.x / viewport_size.x,
		screen_pos.y / viewport_size.y
	)
	
	for shader in shaders:
		shader.set_shader_parameter("light_position", light_pos)

# Adjust the flashlight radius
func adjust_radius(amount: float):
	var new_radius = DEFAULT_RADIUS
	
	# Get current radius from first shader if available
	if shaders.size() > 0:
		new_radius = shaders[0].get_shader_parameter("light_radius")
	
	new_radius = clamp(new_radius + amount, MIN_RADIUS, MAX_RADIUS)
	
	for shader in shaders:
		shader.set_shader_parameter("light_radius", new_radius)
	
	print("Flashlight radius: ", new_radius)

# Adjust the flashlight intensity
func adjust_intensity(amount: float):
	var new_intensity = DEFAULT_INTENSITY
	
	# Get current intensity from first shader if available
	if shaders.size() > 0:
		new_intensity = shaders[0].get_shader_parameter("light_intensity")
	
	new_intensity = clamp(new_intensity + amount, MIN_INTENSITY, MAX_INTENSITY)
	
	for shader in shaders:
		shader.set_shader_parameter("light_intensity", new_intensity)
	
	print("Flashlight intensity: ", new_intensity)

# Adjust the flashlight edge softness
func adjust_falloff(amount: float):
	var new_falloff = DEFAULT_FALLOFF
	
	# Get current falloff from first shader if available
	if shaders.size() > 0:
		new_falloff = shaders[0].get_shader_parameter("light_falloff")
	
	new_falloff = clamp(new_falloff + amount, MIN_FALLOFF, MAX_FALLOFF)
	
	for shader in shaders:
		shader.set_shader_parameter("light_falloff", new_falloff)
	
	print("Flashlight falloff: ", new_falloff)
