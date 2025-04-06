extends CanvasLayer

signal start_game

func _ready():
	# Center the panel on the screen
	$Panel.position = (get_viewport().size / 2)
	
	# Connect the button's pressed signal
	$Panel/VBoxContainer/StartButton.pressed.connect(_on_start_button_pressed)
	
	# Make the mouse cursor visible in the start menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Setup custom button styling
	#setup_custom_button($Panel/VBoxContainer/StartButton)

func _on_start_button_pressed():
	# Hide the menu
	visible = false
	
	# Emit signal to start the game
	start_game.emit()
	
	# The main script will handle hiding the cursor when game starts

func setup_custom_button(button):
	# Create a base StyleBoxTexture
	var base_style = StyleBoxTexture.new()
	base_style.texture = load("res://assets/ui/9patchrect.png")
	
	# Set the texture margins (these are different in Godot 4)
	base_style.texture_margin_left = 8
	base_style.texture_margin_right = 8
	base_style.texture_margin_top = 8
	base_style.texture_margin_bottom = 8
	
	# Normal state (unmodified)
	var normal_style = base_style.duplicate()
	
	# Pressed state (darker)
	var pressed_style = base_style.duplicate()
	pressed_style.modulate_color = Color(0.7, 0.7, 0.7)  # 30% darker
	
	# Hover state (slightly brighter)
	var hover_style = base_style.duplicate()
	hover_style.modulate_color = Color(1.1, 1.1, 1.1)  # 10% brighter
	
	# Apply styles to the button
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("hover", hover_style)
