extends CharacterBody3D

@onready var particula_dash: GPUParticles3D = $ParticulaDash

@onready var area_atropelamento: Area3D = $AreaAtropelamento
@onready var collision_corpo: CollisionShape3D = $CollisionShape3D
@onready var collision_tampa: CollisionShape3D = $CollisionShape3D2
@onready var _model: Node3D = $Node3D
@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D

# FUMAÇA DO DRIFT (procura os nós pelo nome, onde eles estiverem na cena)
@onready var particula_drift: GPUParticles3D = find_child("ParticulaDrift", true, false)
@onready var marker_esq: Node3D = find_child("Esq", true, false)
@onready var marker_dir: Node3D = find_child("Dir", true, false)

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

# DRIFT (automático)
@export_group("Drift")
@export var velocidade_minima_drift: float = 1.2
## Curva fechada: ângulo (graus) entre a velocidade e o input para COMEÇAR o drift.
@export var angulo_drift: float = 25.0
## Curva aberta (girando a câmera / W+A / W+D): quão rápido o input precisa estar girando (rad/s).
## Menor = drift começa com curvas mais leves.
@export var giro_minimo_drift: float = 1.0
## Ângulo (graus) abaixo do qual a curva é considerada terminada.
@export var angulo_fim_drift: float = 15.0
## Quanto tempo precisa estar "reto" para o drift terminar (evita sair no meio da curva).
@export var tempo_confirmar_fim_drift: float = 0.2
## Tempo mínimo que o drift dura antes de poder terminar.
@export var tempo_minimo_drift: float = 0.3
## Tempo máximo do drift. Só uma segurança, ele termina sozinho quando você volta a ir reto.
@export var duracao_maxima_drift: float = 6.0
## Velocidade MÍNIMA de giro da direção durante o drift (rad/s). Menor = derrapa mais.
@export var velocidade_giro_drift: float = 2.5
## Velocidade MÁXIMA de giro (rad/s). Usada quando falta muito ângulo pra alinhar.
@export var velocidade_giro_maximo_drift: float = 6.0
## Quanto o giro acelera conforme o ângulo restante.
@export var ganho_giro_drift: float = 3.0
## Multiplicador da rotação da câmera enquanto está em drift.
@export var multiplicador_camera_drift: float = 1.3
@export var inclinacao_drift: float = 14.0
@export var altura_drift: float = 0.15
@export var tempo_entre_drifts: float = 0.3
## Velocidade durante o drift em relação à normal (0.75 = perde 25%). Não afeta o dash.
@export_range(0.3, 1.0) var multiplicador_velocidade_drift: float = 0.75
## Marque se a fumaça estiver saindo do lado errado.
@export var inverter_lado_fumaca: bool = false
## Quão rápido a velocidade cai até o valor do drift (unidades/s²). Maior = freia mais forte.
@export var desaceleracao_drift: float = 2.0
## Ângulo extra (graus) que o corpo gira para dentro da curva, "cruzando" o carro.
@export var angulo_derrapagem: float = 15.0
## Tempo mínimo de drift para ganhar o impulso ao sair.
@export var tempo_para_boost_drift: float = 0.6
## Velocidade extra ganha ao sair de um drift longo. Volta ao normal aos poucos.
@export var impulso_boost_drift: float = 2.5
## Quanto o FOV da câmera aumenta durante o drift (graus).
@export var fov_extra_drift: float = 6.0

signal boost_drift

var em_drift := false
var tempo_em_drift := 0.0
var _fov_base: float = 75.0
var _tempo_reto := 0.0
var cooldown_drift := 0.0
var lado_drift := 1.0
var _tween_drift: Tween

# Taxa de giro do input (para detectar curvas abertas)
var giro_input := 0.0
var _dir_input_anterior := Vector3.ZERO

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

	if particula_drift:
		particula_drift.emitting = false

	_fov_base = _camera.fov

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

	var tem_input := move_direction.length_squared() > 0.01

	# TAXA DE GIRO DO INPUT (rad/s, suavizada)
	# Girar a câmera segurando W (ou W+A / W+D) faz a direção desejada girar.
	var giro_instantaneo := 0.0
	if tem_input and _dir_input_anterior.length_squared() > 0.01:
		giro_instantaneo = _dir_input_anterior.signed_angle_to(move_direction, Vector3.UP) / delta

	giro_input = lerpf(giro_input, giro_instantaneo, 1.0 - exp(-12.0 * delta))
	_dir_input_anterior = move_direction if tem_input else Vector3.ZERO

	# COMEÇAR PREPARAÇÃO DO DASH
	if Input.is_action_just_pressed("Dash") and not preparando_dash and not em_dash and tempo_cooldown_dash <= 0.0:
		comecar_preparacao_dash(move_direction)

	# PREPARAÇÃO DO DASH
	if preparando_dash:
		tempo_preparacao -= delta

		if tem_input:
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

	# DETECTAR INÍCIO DO DRIFT
	var velocidade_horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if not em_drift and tem_input and cooldown_drift <= 0.0 \
			and velocidade_horizontal.length_squared() >= velocidade_minima_drift * velocidade_minima_drift:
		var direcao_atual := velocidade_horizontal.normalized()
		var dot: float = clampf(direcao_atual.dot(move_direction), -1.0, 1.0)
		var angulo: float = rad_to_deg(acos(dot))

		# Curva fechada: ângulo grande de uma vez
		var curva_fechada := angulo >= angulo_drift
		# Curva aberta: o input está girando rápido e já existe algum ângulo
		var curva_aberta := absf(giro_input) >= giro_minimo_drift and angulo >= 8.0

		if curva_fechada or curva_aberta:
			comecar_drift(direcao_atual, move_direction)

	# MOVIMENTO DURANTE DRIFT
	if em_drift:
		tempo_em_drift += delta

		if not tem_input:
			# Soltou as teclas: encerra o drift.
			terminar_drift()
		else:
			var vel_h := Vector3(velocity.x, 0.0, velocity.z)
			var velocidade_escalar := vel_h.length()
			var direcao_atual := vel_h.normalized() if velocidade_escalar > 0.01 else move_direction

			var angulo_restante := direcao_atual.signed_angle_to(move_direction, Vector3.UP)

			# Se o jogador inverteu a curva (esq <-> dir), troca o lado do drift
			var novo_lado := lado_drift
			if absf(angulo_restante) > deg_to_rad(15.0):
				novo_lado = -signf(angulo_restante)
			elif absf(giro_input) >= giro_minimo_drift:
				novo_lado = -signf(giro_input)

			if novo_lado != lado_drift:
				trocar_lado_drift(novo_lado, move_direction)

			# Giro adaptativo: quanto mais falta pra alinhar, mais rápido gira.
			var giro := clampf(
				absf(angulo_restante) * ganho_giro_drift,
				velocidade_giro_drift,
				velocidade_giro_maximo_drift
			)
			var passo := clampf(angulo_restante, -giro * delta, giro * delta)
			var nova_direcao := direcao_atual.rotated(Vector3.UP, passo)

			# Perde um pouco de velocidade durante o drift (não afeta o dash)
			var velocidade_alvo_drift := velocidade_atual
			if not em_dash:
				velocidade_alvo_drift *= multiplicador_velocidade_drift

			velocidade_escalar = move_toward(velocidade_escalar, velocidade_alvo_drift, desaceleracao_drift * delta)

			velocity.x = nova_direcao.x * velocidade_escalar
			velocity.z = nova_direcao.z * velocidade_escalar

			# Terminou a curva? Precisa estar alinhado E sem estar girando, por um tempinho.
			var angulo_final := absf(nova_direcao.signed_angle_to(move_direction, Vector3.UP))
			var alinhado := angulo_final <= deg_to_rad(angulo_fim_drift)
			var ainda_girando := absf(giro_input) >= giro_minimo_drift * 0.5

			if alinhado and not ainda_girando:
				_tempo_reto += delta
			else:
				_tempo_reto = 0.0

			var terminou := tempo_em_drift >= tempo_minimo_drift and _tempo_reto >= tempo_confirmar_fim_drift

			if terminou or tempo_em_drift >= duracao_maxima_drift:
				terminar_drift(terminou)

	# MOVIMENTO NORMAL / DASH
	else:
		velocity = velocity.move_toward(move_direction * velocidade_atual, acceleration * delta)

	move_and_slide()
	verificar_colisao_quebravel()

	# ROTAÇÃO DO CORTADOR
	if tem_input:
		var target_rotation := atan2(move_direction.x, move_direction.z)

		# Durante o drift o corpo gira um pouco além, apontando para dentro da curva
		if em_drift:
			target_rotation += lado_drift * deg_to_rad(angulo_derrapagem)

		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

	# CAMERA
	atualizar_camera(delta)

	# FUMAÇA DO DRIFT
	atualizar_fumaca_drift()

	# ATROPELAMENTO
	if em_dash:
		verificar_atropelamento()


# =========================================================
# CAMERA
# =========================================================

func atualizar_camera(delta: float):
	_camera_pivot.global_position = global_position

	# Mouse vai esq q dir (gira mais rápido durante o drift)
	if _camera_input_x != 0.0:
		var multiplicador := multiplicador_camera_drift if em_drift else 1.0
		_camera_pivot.rotation.y -= _camera_input_x * delta * multiplicador
		_camera_input_x = 0.0

	# Abre o FOV durante o drift para dar sensação de velocidade
	var fov_alvo := _fov_base + (fov_extra_drift if em_drift else 0.0)
	_camera.fov = lerpf(_camera.fov, fov_alvo, 1.0 - exp(-4.0 * delta))

	var inclinacao_alvo := 0.0

	if em_drift:
		# Inclina seguindo o drift
		inclinacao_alvo = deg_to_rad(inclinacao_camera_drift) * lado_drift

	# Faz a câmera inclinar até o ângulo usando lerp pra suavizar
	_camera_pivot.rotation.z = lerp_angle(
		_camera_pivot.rotation.z,
		inclinacao_alvo,
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

func comecar_drift(direcao_atual: Vector3, nova_direcao: Vector3):
	if em_drift:
		return

	em_drift = true
	tempo_em_drift = 0.0
	_tempo_reto = 0.0

	# Lado da inclinação: primeiro pelo ângulo da curva, depois pela taxa de giro do input
	var angulo_curva := direcao_atual.signed_angle_to(nova_direcao, Vector3.UP)

	if absf(angulo_curva) > deg_to_rad(5.0):
		lado_drift = -signf(angulo_curva)
	elif absf(giro_input) > 0.1:
		lado_drift = -signf(giro_input)

	_aplicar_pose_drift(0.15)
	driftou.emit(nova_direcao)


func trocar_lado_drift(novo_lado: float, nova_direcao: Vector3):
	lado_drift = novo_lado
	_tempo_reto = 0.0
	_aplicar_pose_drift(0.2)
	driftou.emit(nova_direcao)


func _aplicar_pose_drift(duracao: float):
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

	if _tween_drift and _tween_drift.is_valid():
		_tween_drift.kill()

	_tween_drift = create_tween()
	_tween_drift.set_parallel(true)

	_tween_drift.tween_property(_model, "transform", transform_drift_modelo, duracao)
	_tween_drift.tween_property(collision_corpo, "transform", transform_drift_corpo, duracao)
	_tween_drift.tween_property(collision_tampa, "transform", transform_drift_tampa, duracao)
	_tween_drift.tween_property(area_atropelamento, "transform", transform_drift_area, duracao)


func atualizar_fumaca_drift():
	if particula_drift == null:
		return

	if not em_drift:
		particula_drift.emitting = false
		return

	# lado_drift > 0 = drift para a esquerda -> marker Esq. lado_drift < 0 -> marker Dir.
	var esquerda := lado_drift > 0.0
	if inverter_lado_fumaca:
		esquerda = not esquerda

	var marker := marker_esq if esquerda else marker_dir

	if marker == null:
		return

	# A partícula é única: move ela para o marker do lado do drift
	particula_drift.global_transform = marker.global_transform
	particula_drift.emitting = true


func terminar_drift(dar_boost: bool = false):
	if not em_drift:
		return

	# Saiu de um drift longo: ganha um impulso na direção que está indo
	if dar_boost and tempo_em_drift >= tempo_para_boost_drift:
		var vel_h := Vector3(velocity.x, 0.0, velocity.z)
		if vel_h.length() > 0.5:
			var com_impulso := vel_h.normalized() * (vel_h.length() + impulso_boost_drift)
			velocity.x = com_impulso.x
			velocity.z = com_impulso.z
			boost_drift.emit()

	em_drift = false
	tempo_em_drift = 0.0
	_tempo_reto = 0.0
	cooldown_drift = tempo_entre_drifts

	if _tween_drift and _tween_drift.is_valid():
		_tween_drift.kill()

	_tween_drift = create_tween()
	_tween_drift.set_parallel(true)

	_tween_drift.tween_property(_model, "transform", transform_original_modelo, 0.25)
	_tween_drift.tween_property(collision_corpo, "transform", transform_original_collision_corpo, 0.25)
	_tween_drift.tween_property(collision_tampa, "transform", transform_original_collision_tampa, 0.25)
	_tween_drift.tween_property(area_atropelamento, "transform", transform_original_area, 0.25)


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
