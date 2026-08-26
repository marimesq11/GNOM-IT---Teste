extends CharacterBody3D


const SPEED = 2.0
const JUMP_VELOCITY = 4.5
const ROTATION_SPEED = 1


func _physics_process(delta: float) -> void:
	# Gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movimento
	var input_dir := Input.get_vector(
		"Andar_Esquerda",
		"Andar_Direita",
		"Andar_Frente",
		"Andar_Tras"
	)

	var direction := (
		transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	).normalized()

	if direction:
		velocity.x = -direction.x * SPEED
		velocity.z = -direction.z * SPEED
		
		# Rotação suave
		rotacionar_para_movimento(-direction, delta)

	else:
		velocity.x = -move_toward(velocity.x, 0, SPEED)
		velocity.z = -move_toward(velocity.z, 0, SPEED)

	move_and_slide()


func rotacionar_para_movimento(direction: Vector3, delta: float) -> void:
	if direction.length() > 0.01:
		var angulo_alvo = atan2(direction.x, direction.z)

		rotation.y = lerp_angle(
			rotation.y,
			angulo_alvo,
			ROTATION_SPEED * delta
		)
