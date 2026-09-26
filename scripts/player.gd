extends CharacterBody3D

signal coin_collected

@export_subgroup("Components")
@export var view: Node3D

@export_subgroup("Properties")
@export var movement_speed = 250
@export var jump_strength = 7

var movement_velocity: Vector3
var rotation_direction: float
var gravity = 0

var previously_floored = false

var jump_single = true
var jump_double = true

var coins = 0

@onready var particles_trail = $ParticlesTrail
@onready var sound_footsteps = $SoundFootsteps
@onready var model = $Character
@onready var animation = $Character/AnimationPlayer

const TRACKPAD_DEADZONE = 0.05
var xr_trackpad: XRController3D = null
var xr_trackpad_touched := false
var xr_trackpad_origin := Vector2(0, 0)

var original_floor_snap_length = 0

# Functions

func _ready() -> void:
	original_floor_snap_length = floor_snap_length
	if OS.has_feature("xr"):
		xr_trackpad =  get_node_or_null("/root/XrMain/XROrigin3D/SpatialTrackpad")
		if not xr_trackpad:
			printerr("Unable to retrieve xr trackpad")
		else:
			print("Connecting to xr trackpad...")
			xr_trackpad.button_pressed.connect(_on_spatial_trackpad_button_pressed)
			xr_trackpad.button_released.connect(_on_spatial_trackpad_button_released)
			xr_trackpad.input_float_changed.connect(_on_spatial_trackpad_input_float_changed)


func _get_accumulated_scale() -> Vector3:
	return global_transform.basis.get_scale()

func _on_spatial_trackpad_button_pressed(action_name: String) -> void:
	if action_name == "primary_touch":
		xr_trackpad_touched = true
		xr_trackpad_origin = xr_trackpad.get_vector2("primary")
	
	if action_name == "secondary_touch":
		# Disable to allow consumption of the scroll gesture in view.gd
		xr_trackpad_touched = false

func _on_spatial_trackpad_button_released(action_name: String) -> void:
	if action_name == "primary_touch":
		xr_trackpad_touched = false
	
	if action_name == "secondary_touch":
		xr_trackpad_touched = xr_trackpad.is_button_pressed("primary_touch")
		if xr_trackpad_touched:
			xr_trackpad_origin = xr_trackpad.get_vector2("primary")
	
	if action_name == "ax_button":
		if jump_single or jump_double:
			jump()

var jump_triggered = false
func _on_spatial_trackpad_input_float_changed(action_name: String, value: float) -> void:
	if action_name == "trigger":
		if value >= 0.25:
			if not jump_triggered:
				if jump_single or jump_double:
					jump()
				jump_triggered = true
		else:
			jump_triggered = false

func _physics_process(delta):

	# Handle functions

	handle_controls(delta)
	handle_gravity(delta)

	handle_effects(delta)

	# Movement
	var accumulated_scale = _get_accumulated_scale()
	
	# It's necessary to scale the `floor_snap_length` to ensure proper floor collision detection.
	floor_snap_length = original_floor_snap_length * accumulated_scale.x

	var applied_velocity: Vector3

	var scaled_movement_velocity = movement_velocity * accumulated_scale
	applied_velocity = velocity.lerp(scaled_movement_velocity, delta * 10)
	applied_velocity.y = -gravity * accumulated_scale.x

	velocity = applied_velocity
	move_and_slide()

	# Rotation

	if Vector2(velocity.z, velocity.x).length() > 0:
		rotation_direction = Vector2(velocity.z, velocity.x).angle()

	rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 10)

	# Falling/respawning

	if position.y < -10:
		get_tree().reload_current_scene()

	# Animation for scale (jumping and landing)

	model.scale = model.scale.lerp(Vector3(1, 1, 1), delta * 10)

	# Animation when landing

	if is_on_floor() and gravity > 2 and !previously_floored:
		model.scale = Vector3(1.25, 0.75, 1.25)
		Audio.play("res://sounds/land.ogg")

	previously_floored = is_on_floor()

# Handle animation(s)

func handle_effects(delta):

	particles_trail.emitting = false
	sound_footsteps.stream_paused = true

	if is_on_floor():
		var horizontal_velocity = Vector2(velocity.x, velocity.z)
		var speed_factor = horizontal_velocity.length() / movement_speed / delta / _get_accumulated_scale().x
		if speed_factor > 0.05:
			if animation.current_animation != "walk":
				animation.play("walk", 0.1)

			if speed_factor > 0.3:
				sound_footsteps.stream_paused = false
				sound_footsteps.pitch_scale = speed_factor

			if speed_factor > 0.75:
				particles_trail.emitting = true

		elif animation.current_animation != "idle":
			animation.play("idle", 0.1)
			
		if animation.current_animation == "walk":
			animation.speed_scale = speed_factor
		else:
			animation.speed_scale = 1.0
			
	elif animation.current_animation != "jump":
		animation.play("jump", 0.1)

# Handle movement input

func handle_controls(delta):

	# Movement

	var input := Vector3.ZERO

	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	if xr_trackpad and xr_trackpad_touched:
		var current_pos = xr_trackpad.get_vector2("primary")
		var delta_pos = current_pos - xr_trackpad_origin
		if abs(delta_pos.x) >= TRACKPAD_DEADZONE:
			input.x += 3 * delta_pos.x
		if abs(delta_pos.y) >= TRACKPAD_DEADZONE:
			input.z += 3 * delta_pos.y

	input = input.rotated(Vector3.UP, view.rotation.y)
	
	if input.length() > 1:
		input = input.normalized()

	movement_velocity = input * movement_speed * delta

	# Jumping

	if Input.is_action_just_pressed("jump"):

		if jump_single or jump_double:
			jump()

# Handle gravity

func handle_gravity(delta):

	gravity += 25 * delta

	if gravity > 0 and is_on_floor():

		jump_single = true
		gravity = 0

# Jumping

func jump():

	Audio.play("res://sounds/jump.ogg")

	gravity = -jump_strength

	model.scale = Vector3(0.5, 1.5, 0.5)

	if jump_single:
		jump_single = false;
		jump_double = true;
	else:
		jump_double = false;

# Collecting coins

func collect_coin():

	coins += 1

	coin_collected.emit(coins)
