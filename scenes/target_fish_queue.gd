extends Control

signal target_completed(fish_type)

# UI settings
@export var panel_width: float = 1060  # Much wider for horizontal layout
@export var panel_height: float = 120  # Shorter for horizontal layout
@export var item_width: float = 120    # New item width instead of height
@export var item_height: float = 100   # Keep same height for items
@export var margin: float = 10
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.8)
@export var title_color: Color = Color(1, 1, 1, 1)

# Target queue settings
var fish_queue = []
var target_sprites = []
var current_target_index = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	# Set up the panel container - now at the top of the screen
	size = Vector2(panel_width, panel_height)
	position = Vector2((get_viewport_rect().size.x - panel_width) / 2, margin)  # Centered at top
	
	# Create title label
	var title = Label.new()
	title.text = "TARGET FISH"
	title.position = Vector2(margin, margin)
	title.add_theme_color_override("font_color", title_color)
	add_child(title)

# Add fish types to the target queue
func set_target_fish(fish_types):
	# Clear existing queue
	clear_queue()
	
	# Add new fish to queue
	fish_queue = fish_types.duplicate()
	
	# Create visual representation
	update_queue_display()

# Clear the entire queue
func clear_queue():
	fish_queue.clear()
	
	# Remove all visual sprites
	for sprite in target_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	
	target_sprites.clear()
	current_target_index = 0

# Update the visual representation of the queue
func update_queue_display():
	# Remove old sprites
	for sprite in target_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	
	target_sprites.clear()
	
	# Create new sprites for each fish in queue - now horizontally arranged
	var x_offset = panel_width / 2 - (fish_queue.size() * (item_width + 5)) / 2  # Center fish items
	
	for i in range(fish_queue.size()):
		var fish_container = Control.new()
		fish_container.position = Vector2(x_offset, 40)  # Fixed vertical position below title
		fish_container.size = Vector2(item_width, item_height)
		add_child(fish_container)
		
		# Highlight current target (add this first so it's behind the sprite)
		if i == current_target_index:
			var highlight = ColorRect.new()
			highlight.size = Vector2(item_width, item_height)
			highlight.color = Color(1, 0.8, 0, 0.3)  # Yellow highlight
			highlight.z_index = -1  # Behind the sprite
			fish_container.add_child(highlight)
		
		# Center container for the fish sprite
		var center_container = CenterContainer.new()
		center_container.size = Vector2(item_width, item_height)
		fish_container.add_child(center_container)
		
		# Fish sprite with dynamic scaling
		var sprite = Sprite2D.new()
		var texture = load(fish_queue[i])
		sprite.texture = texture
		
		# Calculate the scaling factor to fit the container while maintaining aspect ratio
		var max_dimension = max(texture.get_width(), texture.get_height())
		var container_max = min(item_width - 20, item_height - 30)  # More padding for better appearance
		var scale_factor = container_max / max_dimension
		
		sprite.scale = Vector2(scale_factor, scale_factor)
		center_container.add_child(sprite)
		
		# Add "CURRENT" text beneath the fish
		if i == current_target_index:
			var label = Label.new()
			label.text = "CURRENT"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # Center the text
			label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			label.position = Vector2(0, item_height - 20)
			label.size = Vector2(item_width, 20)
			fish_container.add_child(label)
		
		target_sprites.append(fish_container)
		x_offset += item_width + 5  # Spacing between items horizontally

# Complete the current target and advance to the next one
func complete_current_target():
	if fish_queue.size() == 0 or current_target_index >= fish_queue.size():
		return false
	
	# Get the current target fish type
	var completed_fish = fish_queue[current_target_index]
	
	# Remove from queue
	fish_queue.remove_at(current_target_index)
	
	# Update display
	update_queue_display()
	
	# Emit signal with the type that was completed
	emit_signal("target_completed", completed_fish)
	
	return true

# Check if a specific fish texture path matches the current target
func is_current_target(fish_texture_path):
	if fish_queue.size() == 0 or current_target_index >= fish_queue.size():
		return false
		
	return fish_queue[current_target_index] == fish_texture_path

# Draw background panel
func _draw():
	# Draw background panel
	draw_rect(Rect2(0, 0, panel_width, panel_height), background_color) 
