extends CharacterBody3D

@onready var particula_dash: GPUParticles3D = $ParticulaDash

@onready var area_atropelamento: Area3D = $AreaAtropelamento
@onready var collision_corpo: CollisionShape3D = $CollisionShape3D
@onready var collision_tampa: CollisionShape3D = $CollisionShape3D2
@onready var _model: Node3D = $Node3D
@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D

# VIDA
@export_group("Vida")
@export var vida_maxima: float = 100.0
var vida: float

signal vida_alterada(vida_atual, vida_max)
signal morreu

# MOVIMENTO
@export_group("Movement")
@export var move_speed: float = 5.0
@export var acceleration: float = 5.0
@export var rotation_speed: float = 3.0

# CAMERA
@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity: float = 0.25
@export var inclinacao_camera_drift: float = 5.0
@export var velocidade_inclinacao_camera: float = 4.0

var _camera_input_x: float = 0.0

# DASH
@export_group("Dash")
@export var velocidade_dash: float = 8.0
@export var tempo_preparacao_dash: float = 0.2
@export var duracao_dash: float = 0.5
@export var cooldown_dash: float = 0.8
@export var velocidade_preparacao: float = 0.85

var preparando_dash := false
var em_dash := false
var tempo_preparacao := 0.0
var tempo_dash := 0.0
var tempo_cooldown_dash := 0.0
var direcao_dash := Vector3.ZERO

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

# TRANSFORMS ORIGINAIS
var transform_original_modelo: Transform3D
var transform_original_collision_corpo: Transform3D
var transform_original_collision_tampa: Transform3D
var transform_original_area: Transform3D

signal driftou(direcao: Vector3)


func _ready():
	vida = vida_maxima

	transform_original_modelo = _model.transform
	transform_original_collision_corpo = collision_corpo.transform
	transform_original_collision_tampa = collision_tampa.transform
	transform_original_area = area_atropelamento.transform

	vida_alterada.emit(vida, vida_maxima)
	area_atropelamento.body_entered.connect(_quando_atropelar)

	# A câmera não herda a rotação do CharacterBody.
	_camera_pivot.top_level = true
	_camera_pivot.global_position = global_position

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Só usamos o movimento horizontal do mouse.
		_camera_input_x = event.screen_relative.x * mouse_sensitivity


func _physics_process(delta: float) -> void:
	# COOLDOWNS
	if cooldown_drift > 0.0:
		cooldown_drift -= delta

	if tempo_cooldown_dash > 0.0:
		tempo_cooldown_dash -= delta

	# INPUT
	var raw_input := Input.get_vector("Andar_Esquerda", "Andar_Direita", "Andar_Frente", "Andar_Tras")

	# MOVIMENTO RELATIVO À CAMERA
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x

	forward.y = 0.0
	right.y = 0.0

	forward = forward.normalized()
	right = right.normalized()

	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0

	if move_direction.length_squared() > 0.0001:
		move_direction = move_direction.normalized()

	# COMEÇAR PREPARAÇÃO DO DASH
	if Input.is_action_just_pressed("Dash") and not preparando_dash and not em_dash and tempo_cooldown_dash <= 0.0:
		comecar_preparacao_dash(move_direction)

	# PREPARAÇÃO DO DASH
	if preparando_dash:
		tempo_preparacao -= delta

		if move_direction.length_squared() > 0.01:
			direcao_dash = move_direction

		if tempo_preparacao <= 0.0:
			comecar_dash(move_direction)

	# TEMPO DO DASH
	if em_dash:
		tempo_dash -= delta

		if tempo_dash <= 0.0:
			terminar_dash()

	# VELOCIDADE ATUAL
	var velocidade_atual := move_speed

	if preparando_dash:
		velocidade_atual = move_speed * velocidade_preparacao

	if em_dash:
		velocidade_atual = velocidade_dash

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

		var velocidade_desejada := move_direction * velocidade_atual
		var alvo_drift := velocidade_drift.lerp(velocidade_desejada, forca_drift)

		velocity.x = move_toward(velocity.x, alvo_drift.x, acceleration * 0.45 * delta)
		velocity.z = move_toward(velocity.z, alvo_drift.z, acceleration * 0.45 * delta)

		if tempo_drift <= 0.0:
			terminar_drift()

	# MOVIMENTO NORMAL / DASH
	else:
		velocity = velocity.move_toward(move_direction * velocidade_atual, acceleration * delta)

	move_and_slide()
	verificar_colisao_quebravel()

	# ROTAÇÃO DO CORTADOR
	if move_direction.length_squared() > 0.01:
		var target_rotation := atan2(move_direction.x, move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

	# CAMERA
	atualizar_camera(delta)

	# ATROPELAMENTO
	if em_dash:
		verificar_atropelamento()


# =========================================================
# CAMERA
# =========================================================

func atualizar_camera(delta: float):
	_camera_pivot.global_position = global_position

	# Mouse vai esq q dir
	if _camera_input_x != 0.0:
		_camera_pivot.rotation.y -= _camera_input_x * delta
		_camera_input_x = 0.0

	var inclinacao_alvo := 0.0

	if em_drift:
		#Inclina seguindo o drift
		inclinacao_alvo = deg_to_rad(inclinacao_camera_drift) * lado_drift

	#Faz a camera inclinar  ate o ângulo usando lerp pra suaviz
	_camera_pivot.rotation.z = lerp_angle(_camera_pivot.rotation.z,inclinacao_alvo,
	1.0 - exp(-velocidade_inclinacao_camera * delta)
	)


# =========================================================
# DASH
# =========================================================

func comecar_preparacao_dash(move_direction: Vector3):
	if preparando_dash or em_dash or tempo_cooldown_dash > 0.0:
		return

	preparando_dash = true
	tempo_preparacao = tempo_preparacao_dash

	if move_direction.length_squared() > 0.01:
		direcao_dash = move_direction
	else:
		direcao_dash = global_basis.z.normalized()


func comecar_dash(move_direction: Vector3):
	preparando_dash = false
	em_dash = true

	tempo_preparacao = 0.0
	tempo_dash = duracao_dash

	if move_direction.length_squared() > 0.01:
		direcao_dash = move_direction

	if direcao_dash.length_squared() <= 0.01:
		direcao_dash = global_basis.z.normalized()

	particula_dash.emitting = true
	particula_dash.restart()


func terminar_dash():
	if not em_dash:
		return

	em_dash = false
	tempo_dash = 0.0
	tempo_cooldown_dash = cooldown_dash

	particula_dash.emitting = false

# =========================================================
# DRIFT
# =========================================================

func comecar_drift(_direcao_atual: Vector3, nova_direcao: Vector3):
	if em_drift:
		return

	em_drift = true
	tempo_drift = duracao_drift
	cooldown_drift = tempo_entre_drifts
	velocidade_drift = velocity

	var direita_cortador := global_basis.x
	var lado_movimento := direita_cortador.dot(nova_direcao)

	if lado_movimento > 0.0:
		lado_drift = -1.0
	else:
		lado_drift = 1.0

	var angulo := deg_to_rad(inclinacao_drift) * lado_drift
	var rotacao_drift := Transform3D(Basis(Vector3.FORWARD, angulo), Vector3.ZERO)

	var transform_drift_modelo := rotacao_drift * transform_original_modelo
	var transform_drift_corpo := rotacao_drift * transform_original_collision_corpo
	var transform_drift_tampa := rotacao_drift * transform_original_collision_tampa
	var transform_drift_area := rotacao_drift * transform_original_area

	transform_drift_modelo.origin.y += altura_drift
	transform_drift_corpo.origin.y += altura_drift
	transform_drift_tampa.origin.y += altura_drift
	transform_drift_area.origin.y += altura_drift

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(_model, "transform", transform_drift_modelo, 0.15)
	tween.tween_property(collision_corpo, "transform", transform_drift_corpo, 0.15)
	tween.tween_property(collision_tampa, "transform", transform_drift_tampa, 0.15)
	tween.tween_property(area_atropelamento, "transform", transform_drift_area, 0.15)

	driftou.emit(nova_direcao)


func terminar_drift():
	if not em_drift:
		return

	em_drift = false

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(_model, "transform", transform_original_modelo, 0.25)
	tween.tween_property(collision_corpo, "transform", transform_original_collision_corpo, 0.25)
	tween.tween_property(collision_tampa, "transform", transform_original_collision_tampa, 0.25)
	tween.tween_property(area_atropelamento, "transform", transform_original_area, 0.25)


# =========================================================
# ATROPELAMENTO
# =========================================================

func _quando_atropelar(body):
	# Só mata durante o dash.
	if not em_dash:
		return

	if not body.is_in_group("atropelavel"):
		return

	if body.has_method("morrer_atropelado"):
		body.morrer_atropelado()


func verificar_atropelamento():
	if not em_dash:
		return

	for body in area_atropelamento.get_overlapping_bodies():
		if body.is_in_group("atropelavel") and body.has_method("morrer_atropelado"):
			body.morrer_atropelado()


# =========================================================
# VIDA
# =========================================================

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

	if collision_corpo:
		collision_corpo.set_deferred("disabled", true)

	if collision_tampa:
		collision_tampa.set_deferred("disabled", true)

	if area_atropelamento:
		area_atropelamento.set_deferred("monitoring", false)
		area_atropelamento.set_deferred("monitorable", false)

func verificar_colisao_quebravel():
	for i in get_slide_collision_count():
		var colisao = get_slide_collision(i)
		var objeto = colisao.get_collider()

		if objeto.is_in_group("Quebravel"):
			objeto.queue_free()
