extends CharacterBody3D

@onready var area_atropelamento: Area3D = $AreaAtropelamento
@onready var _model: Node3D= $Node3D
@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D

# VIDA
@export_group("Vida")
@export var vida_maxima: float = 100.0
var vida: float

signal vida_alterada(vida_atual, vida_max)
signal morreu

# CAMERA
@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var tilt_upper_limit := PI / 3.0
@export var tilt_lower_limit := -PI / 8.0

var _camera_input_direction := Vector2.ZERO

# MOVIMENTO
@export_group("Movement")
@export var move_speed := 2.0
@export var acceleration := 5.0
@export var rotation_speed := 3.0

# DRIFT
@export_group("Drift")
@export var velocidade_minima_drift: float = 1.2
@export var angulo_drift: float = 40.0
@export var duracao_drift: float = 0.7
@export_range(0.0, 1.0) var forca_drift: float = 0.3
@export var inclinacao_drift: float = 14.0
@export var altura_drift: float = 0.15
@export var tempo_entre_drifts: float = 0.5

var em_drift := false
var tempo_drift := 0.0
var cooldown_drift := 0.0
var velocidade_drift := Vector3.ZERO
var lado_drift := 1.0

var altura_original_modelo: float
var rotacao_z_original_modelo: float

signal driftou(direcao: Vector3)


func _ready():
	vida = vida_maxima
	altura_original_modelo = _model.position.y
	rotacao_z_original_modelo = _model.rotation.z

	vida_alterada.emit(vida, vida_maxima)
	area_atropelamento.body_entered.connect(_quando_atropelar)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_input_direction = event.screen_relative * mouse_sensitivity


func _physics_process(delta: float) -> void:
	# CAMERA
	if _camera_input_direction != Vector2.ZERO:
		_camera_pivot.rotation.x += _camera_input_direction.y * delta
		_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit)
		_camera_pivot.rotation.y -= _camera_input_direction.x * delta
		_camera_input_direction = Vector2.ZERO

	# MOVIMENTO
	var raw_input := Input.get_vector("Andar_Esquerda", "Andar_Direita", "Andar_Frente", "Andar_Tras")

	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x

	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0

	if move_direction.length_squared() > 0.0001:
		move_direction = move_direction.normalized()

	# COOLDOWN
	if cooldown_drift > 0.0:
		cooldown_drift -= delta

	# DETECTAR DRIFT
	var velocidade_horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if not em_drift and move_direction.length_squared() > 0.01 and velocidade_horizontal.length_squared() >= velocidade_minima_drift * velocidade_minima_drift and cooldown_drift <= 0.0:
		var direcao_atual := velocidade_horizontal.normalized()
		var dot: float = clampf(direcao_atual.dot(move_direction), -1.0, 1.0)
		var angulo: float = rad_to_deg(acos(dot))

		if angulo >= angulo_drift:
			comecar_drift(direcao_atual, move_direction)

	# MOVIMENTO DURANTE DRIFT
	if em_drift:
		tempo_drift -= delta

		var velocidade_desejada := move_direction * move_speed
		var alvo_drift := velocidade_drift.lerp(velocidade_desejada, forca_drift)

		velocity.x = move_toward(velocity.x, alvo_drift.x, acceleration * 0.45 * delta)
		velocity.z = move_toward(velocity.z, alvo_drift.z, acceleration * 0.45 * delta)

		if tempo_drift <= 0.0:
			terminar_drift()

	# MOVIMENTO NORMAL
	else:
		velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)

	move_and_slide()

	# ROTAÇÃO
	if move_direction.length_squared() > 0.01:
		var target_rotation := atan2(move_direction.x, move_direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_rotation, rotation_speed * delta)


func comecar_drift(direcao_atual: Vector3, nova_direcao: Vector3):
	if em_drift:
		return

	em_drift = true
	tempo_drift = duracao_drift
	cooldown_drift = tempo_entre_drifts
	velocidade_drift = velocity

	var cruzamento: float = direcao_atual.cross(nova_direcao).y
	lado_drift = -1.0 if cruzamento < 0.0 else 1.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "rotation:z", rotacao_z_original_modelo + deg_to_rad(inclinacao_drift) * lado_drift, 0.15)
	tween.tween_property(_model, "position:y", altura_original_modelo + altura_drift, 0.15)

	driftou.emit(nova_direcao)


func terminar_drift():
	if not em_drift:
		return

	em_drift = false

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "rotation:z", rotacao_z_original_modelo, 0.25)
	tween.tween_property(_model, "position:y", altura_original_modelo, 0.25)


func tomar_dano(dano: float):
	if vida <= 0.0:
		return

	vida = clamp(vida - dano, 0.0, vida_maxima)
	vida_alterada.emit(vida, vida_maxima)

	if vida <= 0.0:
		morrer()


func morrer():
	morreu.emit()

	hide()
	set_physics_process(false)
	set_process(false)

	var collision = get_node_or_null("CollisionShape3D")

	if collision:
		collision.set_deferred("disabled", true)

	if area_atropelamento:
		area_atropelamento.set_deferred("monitoring", false)
		area_atropelamento.set_deferred("monitorable", false)


func _quando_atropelar(body):
	if body.is_in_group("atropelavel") and body.has_method("morrer_atropelado"):
		body.morrer_atropelado()
