extends CanvasLayer

signal resume_game
signal quit_game

func _ready():
	# Hide menu initially
	visible = false
	
	# Center the panel on the screen
	$Panel.position = (get_viewport().size / 2)
	
	# Connect button signals
	$Panel/VBoxContainer/ResumeButton.pressed.connect(_on_resume_button_pressed)
	$Panel/VBoxContainer/QuitButton.pressed.connect(_on_quit_button_pressed)
	
	# Setup custom button styling
	setup_custom_button($Panel/VBoxContainer/ResumeButton)
	setup_custom_button($Panel/VBoxContainer/QuitButton)

func show_menu():
	visible = true
	
	# Make cursor visible in pause menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_menu():
	visible = false
	
	# Hide cursor again when resuming (main.gd will handle this)
	# Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _on_resume_button_pressed():
	hide_menu()
	resume_game.emit()

func _on_quit_button_pressed():
	quit_game.emit()

func setup_custom_button(button):
	# Create a base StyleBoxTexture
	var base_style = StyleBoxTexture.new()
	base_style.texture = load("res://assets/ui/9patchrect.png")
	
	# Set the texture margins
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
