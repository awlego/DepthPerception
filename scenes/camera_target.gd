extends Area2D

signal fish_captured(fish_count)

@export var rect_size: Vector2 = Vector2(150, 100)
@export var rect_color: Color = Color(1, 1, 1, 1)
@export var line_width: float = 2.0
@export var crosshair_size: float = 10.0  # Size of the crosshair lines
@export var crosshair_color: Color = Color(1, 1, 1, 1)  # White color for crosshair
@export var crosshair_width: float = 1.0  # Thickness of crosshair lines

var collision_shape: CollisionShape2D
var fish_in_viewfinder = []  # For area enter/exit detection
var fully_contained_fish = []  # Fish that are fully within the viewfinder

# Called when the node enters the scene tree for the first time.
func _ready():
	# Create collision shape for detecting fish
	collision_shape = CollisionShape2D.new()
	var rectangle_shape = RectangleShape2D.new()
	rectangle_shape.size = rect_size
	collision_shape.shape = rectangle_shape
	collision_shape.position = Vector2.ZERO  # Center the collision shape
	add_child(collision_shape)
	
	# Request redraw of the viewfinder
	queue_redraw()
	
	# Connect area signals to detect fish
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)

# When an area enters the camera viewfinder
func _on_area_entered(area):
	if area.is_in_group("fish"):
		if not area in fish_in_viewfinder:
			fish_in_viewfinder.append(area)
			print("Fish entered viewfinder: ", fish_in_viewfinder.size())
			emit_signal("fish_captured", fish_in_viewfinder.size())

# When an area exits the camera viewfinder
func _on_area_exited(area):
	if area.is_in_group("fish"):
		if area in fish_in_viewfinder:
			fish_in_viewfinder.erase(area)
			print("Fish exited viewfinder: ", fish_in_viewfinder.size())
			emit_signal("fish_captured", fish_in_viewfinder.size())
		
		# Also remove from fully contained list if it was there
		if area in fully_contained_fish:
			fully_contained_fish.erase(area)

# Calculate which fish are fully contained in the viewfinder
func update_fully_contained_fish():
	fully_contained_fish.clear()
	
	# Camera bounds (in global coordinates)
	var camera_rect = Rect2(
		position - rect_size/2,  # Top-left corner
		rect_size  # Size
	)
	
	# Check each fish in the viewfinder
	for fish in fish_in_viewfinder:
		# Get the fish's sprite dimensions
		var fish_sprite = null
		for child in fish.get_children():
			if child is Sprite2D:
				fish_sprite = child
				break
		
		if fish_sprite:
			# Calculate the fish bounds
			var sprite_scale = fish_sprite.scale
			var texture_size = fish_sprite.texture.get_size()
			var scaled_size = texture_size * sprite_scale
			
			# Fish bounds in global coordinates
			var fish_rect = Rect2(
				fish.global_position - scaled_size/2,  # Top-left
				scaled_size  # Size
			)
			
			# Check if fish is fully contained in camera
			if camera_rect.encloses(fish_rect):
				fully_contained_fish.append(fish)

# Calculate the % of the viewfinder that is covered by a specific fish
# Returns a value between 0.0 and 100.0
func calculate_viewfinder_coverage(fish):
	# Skip if fish isn't visible
	if not fish.visible or not fish.is_active:
		return 0.0
		
	# Get fish sprite
	var fish_sprite = fish.get_node_or_null("Sprite2D")
	if not fish_sprite or not fish_sprite.texture:
		return 0.0
	
	# Get viewfinder rect in global coordinates
	var viewfinder_rect = Rect2(
		global_position - rect_size / 2,
		rect_size
	)
	
	# Calculate total viewfinder area
	var viewfinder_area = rect_size.x * rect_size.y
	
	# Calculate the fish's global rect (accounting for scale)
	var fish_size = fish_sprite.texture.get_size() * fish_sprite.scale
	var fish_rect = Rect2(
		fish.global_position - fish_size / 2,
		fish_size
	)
	
	# Calculate intersection with viewfinder
	var intersection = viewfinder_rect.intersection(fish_rect)
	
	# If there's no intersection, return 0
	if not intersection.has_area():
		return 0.0
		
	# Calculate percentage (clamped between 0-100%)
	var coverage_percentage = (intersection.get_area() / viewfinder_area) * 100.0
	return clamp(coverage_percentage, 0.0, 100.0)

# Get current count of fish in viewfinder
func get_fish_count():
	return fish_in_viewfinder.size()

# Get current count of fully contained fish in viewfinder
func get_fully_contained_fish_count():
	update_fully_contained_fish()
	return fully_contained_fish.size()

# Check if a specific fish is in the viewfinder
func is_fish_in_viewfinder(fish):
	return fish in fish_in_viewfinder

# Check if a specific fish is fully contained in the viewfinder
func is_fish_fully_in_viewfinder(fish):
	update_fully_contained_fish()
	return fish in fully_contained_fish

# Check if a fish is a valid target (either fully contained or covers most of viewfinder)
func is_valid_fish_capture(fish):
	# Special handling for fish16.png
	if fish.texture_path and "fish16.png" in fish.texture_path:
		# Special case for fish16 - use a much lower threshold (10%)
		var coverage = calculate_viewfinder_coverage(fish)
		return coverage >= 10.0  # Only need 10% coverage
	
	# Standard handling for all other fish
	# First check if fish is fully in viewfinder
	if is_fish_fully_in_viewfinder(fish):
		return true
		
	# If not fully contained, check if it covers most of the viewfinder
	var coverage = calculate_viewfinder_coverage(fish)
	return coverage >= 90.0  # 90% coverage threshold

# Custom drawing function to draw the rectangle outline
func _draw():
	# Draw the rectangle outline (4 lines)
	draw_rect(Rect2(-rect_size/2, rect_size), rect_color, false, line_width)  # false = not filled
	
	# Draw crosshair in the center of the rectangle
	
	# Horizontal line of the crosshair
	draw_line(
		Vector2(-crosshair_size/2, 0), 
		Vector2(crosshair_size/2, 0), 
		crosshair_color, 
		crosshair_width
	)
	
	# Vertical line of the crosshair
	draw_line(
		Vector2(0, -crosshair_size/2), 
		Vector2(0, crosshair_size/2), 
		crosshair_color, 
		crosshair_width
	) 
