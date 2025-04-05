extends Area2D

@export var speed_range: Vector2 = Vector2(50, 150)  # Min/max speed range
@export var direction_change_time: float = 2.0  # Time in seconds before changing direction
@export var texture_path: String = ""

var velocity: Vector2
var timer: Timer
var sprite: Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Add to fish group for detection
	add_to_group("fish")
	
	# Set up collision
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20  # Adjust based on your fish size
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Set up sprite
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"  # Name it so we can reference it with $Sprite2D
	if texture_path and texture_path != "":
		sprite.texture = load(texture_path)
		sprite.scale = Vector2(0.2, 0.2)  # Adjust as needed
	add_child(sprite)
	
	# Initial velocity
	randomize_velocity()
	
	# Create timer for direction change
	timer = Timer.new()
	timer.wait_time = randf_range(direction_change_time * 0.5, direction_change_time * 1.5)
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.connect("timeout", change_direction)

# Change fish direction randomly
func change_direction():
	randomize_velocity()

# Randomize the velocity vector
func randomize_velocity():
	velocity = Vector2(
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized() * randf_range(speed_range.x, speed_range.y)
	
	# Update sprite orientation
	if sprite:
		if velocity.x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Move fish
	position += velocity * delta
	
	# Handle screen boundaries - bounce
	var screen_size = get_viewport_rect().size
	var bounce = false
	
	if position.x < 0:
		position.x = 0
		velocity.x = abs(velocity.x)
		bounce = true
	elif position.x > screen_size.x:
		position.x = screen_size.x
		velocity.x = -abs(velocity.x)
		bounce = true
		
	if position.y < 0:
		position.y = 0
		velocity.y = abs(velocity.y)
		bounce = true
	elif position.y > screen_size.y:
		position.y = screen_size.y
		velocity.y = -abs(velocity.y)
		bounce = true
	
	# Update sprite orientation if bounced
	if bounce and sprite:
		if velocity.x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false 