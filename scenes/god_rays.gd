extends ColorRect

class_name GodRays

# Export parameters for the new shader
@export var ray_angle: float = 0.0
@export var ray_position: float = 0.0  # Renamed from 'position' to avoid conflict
@export var spread: float = 0.5
@export var cutoff: float = 0.1
@export var falloff: float = 0.2
@export var edge_fade: float = 0.15
@export var ray_speed: float = 1.0  # Renamed from 'speed' to match our naming convention
@export var ray1_density: float = 8.0
@export var ray2_density: float = 30.0
@export var ray2_intensity: float = 0.3
@export var ray_color: Color = Color(1.0, 0.9, 0.65, 0.8)
@export var hdr: bool = false
@export var seed_value: float = 5.0
@export var max_depth: float = 60.0  # Rays disappear completely beyond this depth
@export var vertical_fade: float = 0.7

# Internal variables
var current_depth = 0.0
var shader_material: ShaderMaterial

func _ready():
	# Set up shader material
	shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://assets/shaders/god_rays.gdshader")
	
	# Apply the shader to this ColorRect
	material = shader_material
	
	# Set initial shader parameters
	update_shader_parameters()
	
	# Make sure this covers the entire screen
	anchors_preset = Control.PRESET_FULL_RECT  # Fill the entire parent container
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input
	
	# Connect to viewport size changed signal
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Set z-index to be behind other elements but in front of background
	# z_index = -30

# Update shader parameters based on exported values
func update_shader_parameters():
	if shader_material:
		shader_material.set_shader_parameter("angle", ray_angle)
		shader_material.set_shader_parameter("position", ray_position)  # Map our ray_position to shader's position
		shader_material.set_shader_parameter("spread", spread)
		shader_material.set_shader_parameter("cutoff", cutoff)
		shader_material.set_shader_parameter("falloff", falloff)
		shader_material.set_shader_parameter("edge_fade", edge_fade)
		shader_material.set_shader_parameter("speed", ray_speed)  # Map our ray_speed to shader's speed
		shader_material.set_shader_parameter("ray1_density", ray1_density)
		shader_material.set_shader_parameter("ray2_density", ray2_density)
		shader_material.set_shader_parameter("ray2_intensity", ray2_intensity)
		shader_material.set_shader_parameter("color", ray_color)
		shader_material.set_shader_parameter("hdr", hdr)
		shader_material.set_shader_parameter("seed", seed_value)
		shader_material.set_shader_parameter("vertical_fade", vertical_fade)
# Update ray visibility based on depth - modify the alpha to fade out rays with depth
func update_depth(depth):
	current_depth = depth
	
	# Calculate a fade factor based on depth
	var fade_factor = 1.0 - clamp(current_depth / max_depth, 0.0, 1.0)
	
	if shader_material:
		# Adjust the color's alpha based on depth
		var depth_adjusted_color = ray_color
		depth_adjusted_color.a = ray_color.a * fade_factor
		shader_material.set_shader_parameter("color", depth_adjusted_color)
	
	# Hide the node completely when below max depth
	visible = (current_depth < max_depth)

# Handle viewport size changes
func _on_viewport_size_changed():
	# Ensure we're still filling the screen
	size = get_viewport_rect().size
