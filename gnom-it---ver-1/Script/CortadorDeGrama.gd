extends CharacterBody3D

@onready var _model : Node3D = $Node3D

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var tilt_upper_limit := PI / 3.0
@export var tilt_lower_limit := -PI / 8.0

@export_group("Movement")
@export var move_speed := 2.0
@export var acceleration := 5.0
@export var rotation_speed := 3

var _camera_input_direction := Vector2.ZERO

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)

	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity


func _physics_process(delta: float) -> void:
	# Rotação da câmera
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(
		_camera_pivot.rotation.x,
		tilt_lower_limit,
		tilt_upper_limit
	)

	_camera_pivot.rotation.y -= _camera_input_direction.x * delta

	_camera_input_direction = Vector2.ZERO


	# Movimento
	var raw_input := Input.get_vector(
		"Andar_Esquerda",
		"Andar_Direita",
		"Andar_Frente",
		"Andar_Tras"
	)

	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x

	var move_direction := forward * raw_input.y + right * raw_input.x

	move_direction.y = 0.0
	move_direction = move_direction.normalized()

	velocity = velocity.move_toward(
		move_direction * move_speed,
		acceleration * delta
	)

	move_and_slide()


	# Faz o personagem olhar para onde está andando
	if move_direction.length() > 0.1:
		var target_rotation := atan2(
			move_direction.x,
			move_direction.z
		)

		_model.rotation.y = lerp_angle(
			_model.rotation.y,
			target_rotation,
			rotation_speed * delta
		)
