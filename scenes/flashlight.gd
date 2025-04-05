# flashlight.gd
extends Node

signal toggled(is_on)

# Flashlight parameters
var shader: ShaderMaterial = null
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

# Initialize the flashlight with a shader
func initialize(material: ShaderMaterial):
	shader = material
	set_parameters()
	
# Set initial flashlight parameters
func set_parameters():
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
	
	if shader:
		shader.set_shader_parameter("flashlight_on", flashlight_on)
		print("Flashlight", " ON" if flashlight_on else " OFF")
		emit_signal("toggled", flashlight_on)

# Update the light position based on screen coordinates
func update_position(screen_pos: Vector2, viewport_size: Vector2):
	if shader:
		var light_pos = Vector2(
			screen_pos.x / viewport_size.x,
			screen_pos.y / viewport_size.y
		)
		shader.set_shader_parameter("light_position", light_pos)

# Adjust the flashlight radius
func adjust_radius(amount: float):
	if shader:
		var current_radius = shader.get_shader_parameter("light_radius")
		var new_radius = clamp(current_radius + amount, MIN_RADIUS, MAX_RADIUS)
		shader.set_shader_parameter("light_radius", new_radius)
		print("Flashlight radius: ", new_radius)

# Adjust the flashlight intensity
func adjust_intensity(amount: float):
	if shader:
		var current_intensity = shader.get_shader_parameter("light_intensity")
		var new_intensity = clamp(current_intensity + amount, MIN_INTENSITY, MAX_INTENSITY)
		shader.set_shader_parameter("light_intensity", new_intensity)
		print("Flashlight intensity: ", new_intensity)

# Adjust the flashlight edge softness
func adjust_falloff(amount: float):
	if shader:
		var current_falloff = shader.get_shader_parameter("light_falloff")
		var new_falloff = clamp(current_falloff + amount, MIN_FALLOFF, MAX_FALLOFF)
		shader.set_shader_parameter("light_falloff", new_falloff)
		print("Flashlight falloff: ", new_falloff)
