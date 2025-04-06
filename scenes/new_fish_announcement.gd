extends Control

signal animation_finished

var fish_name = ""
var tween

func _ready():
	# Set initial size to match the content
	size = Vector2(336, 80)  # Match the width of your three textures combined
	
	# Set initial position below the screen
	position.y = get_viewport_rect().size.y + size.y
	
	# Center horizontally
	position.x = (get_viewport_rect().size.x - size.x) / 2
	
	# Update the label text if we have a fish name
	if fish_name:
		$Label.text = "New Species Identified: " + fish_name + "!"

func show_announcement(species_name):
	# Update fish name and label
	fish_name = species_name
	$Label.text = "New Species Identified: " + fish_name + "!"
	
	# Calculate target positions
	var screen_height = get_viewport_rect().size.y
	var screen_width = get_viewport_rect().size.x
	
	# Start position (below screen)
	var start_y = screen_height + size.y
	
	# End position (at bottom of screen with a small margin)
	var end_y = screen_height - size.y - 20  # 20px margin from bottom
	
	# Center horizontally
	position.x = (screen_width - size.x) / 2
	
	# Reset vertical position
	position.y = start_y
	
	# Create animation
	tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Slide in from bottom
	tween.tween_property(self, "position:y", end_y, 0.5)
	
	# Wait for 4 seconds
	tween.tween_interval(4.0)
	
	# Slide out
	tween.tween_property(self, "position:y", start_y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Signal when complete
	tween.finished.connect(func(): animation_finished.emit())
