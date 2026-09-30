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

const SUAVIZACAO_GIRO_INPUT := 12.0
const DURACAO_ENTRAR_DRIFT := 0.15
const DURACAO_TROCAR_LADO := 0.2
const DURACAO_SAIR_DRIFT := 0.25

# VIDA
@export_group("Vida")
@export var vida_maxima: float = 100.0
var vida: float

signal vida_alterada(vida_atual, vida_max)
signal morreu

# MOVIMENTO
@export_group("Movement")
@export var move_speed: float = 4.5
@export var acceleration: float = 5.5
@export var rotation_speed: float = 3.0

# CAMERA
@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity: float = 0.25
@export var inclinacao_camera_drift: float = 5.0
@export var velocidade_inclinacao_camera: float = 4.0
## Multiplicador da rotação da câmera enquanto está em drift.
@export var multiplicador_camera_drift: float = 1.3
## Quanto o FOV da câmera aumenta durante o drift (graus).
@export var fov_extra_drift: float = 6.0

var _camera_input_x: float = 0.0
var _fov_base: float = 75.0

# DASH
@export_group("Dash")
@export var velocidade_dash: float = 6.5
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

# DRIFT: COMO COMEÇA
@export_group("Drift - Início")
## Velocidade mínima para poder começar o drift.
@export var velocidade_minima_drift: float = 3.0
## Curva fechada: ângulo (graus) entre a velocidade e o input para COMEÇAR o drift. Maior = menos sensível.
@export var angulo_drift: float = 35.0
## Curva aberta (girando a câmera): quão rápido o input precisa girar (rad/s). Maior = menos sensível.
@export var giro_minimo_drift: float = 1.8
## Curva aberta: ângulo mínimo (graus) entre a velocidade e o input para contar como drift.
@export var angulo_minimo_curva_aberta: float = 20.0
## Quanto tempo a condição precisa se manter antes do drift começar (filtra toques rápidos).
@export var tempo_confirmar_inicio_drift: float = 0.1
## Espera depois de um drift para poder driftar de novo.
@export var tempo_entre_drifts: float = 0.5

# DRIFT: COMO TERMINA
@export_group("Drift - Fim")
## Ângulo (graus) abaixo do qual a curva é considerada terminada.
@export var angulo_fim_drift: float = 15.0
## Quanto tempo precisa estar "reto" para o drift terminar (evita sair no meio da curva).
@export var tempo_confirmar_fim_drift: float = 0.2
## Tempo mínimo que o drift dura antes de poder terminar.
@export var tempo_minimo_drift: float = 0.3
## Tempo máximo do drift. Só uma segurança.
@export var duracao_maxima_drift: float = 2.0
## Ângulo (graus) de diferença a partir do qual inverter a curva troca o lado do drift.
@export var angulo_troca_lado_drift: float = 30.0

# DRIFT: COMO SE COMPORTA
@export_group("Drift - Comportamento")
## Velocidade MÍNIMA de giro da direção durante o drift (rad/s).
@export var velocidade_giro_drift: float = 2.5
## Velocidade MÁXIMA de giro (rad/s). Usada quando falta muito ângulo pra alinhar.
@export var velocidade_giro_maximo_drift: float = 6.0
## Quanto o giro acelera conforme o ângulo restante.
@export var ganho_giro_drift: float = 3.0
## Aderência da curva. 1.0 = gira normalmente; menor = derrapa mais (desliza).
@export_range(0.15, 1.0) var fator_derrapagem: float = 0.35
## Tempo (s) no começo do drift em que ele mantém o embalo na direção antiga antes de curvar.
@export var tempo_inercia_drift: float = 0.4
## Quanto o corpo gira mais rápido que a velocidade (aumenta o efeito de derrapar de lado).
@export var multiplicador_rotacao_drift: float = 2.0
## Ângulo extra (graus) que o corpo gira para dentro da curva.
@export var angulo_derrapagem: float = 35.0
## Velocidade durante o drift em relação à normal (0.75 = perde 25%). Não afeta o dash.
@export_range(0.3, 1.0) var multiplicador_velocidade_drift: float = 0.75
## Quão rápido a velocidade cai até o valor do drift (unidades/s²).
@export var desaceleracao_drift: float = 3.0

# DRIFT: VISUAL E EXTRAS
@export_group("Drift - Visual e Boost")
@export var inclinacao_drift: float = 14.0
@export var altura_drift: float = 0.15
## Marque se a fumaça estiver saindo do lado errado.
@export var inverter_lado_fumaca: bool = false
## Tempo mínimo de drift para ganhar o impulso ao sair.
@export var tempo_para_boost_drift: float = 0.6
## Velocidade extra ganha ao sair de um drift longo. Volta ao normal aos poucos.
@export var impulso_boost_drift: float = 2.0

signal driftou(direcao: Vector3)
signal boost_drift

var em_drift := false
var tempo_em_drift := 0.0
var cooldown_drift := 0.0
var lado_drift := 1.0
var _tempo_reto := 0.0
var _tempo_intencao_drift := 0.0
var _tween_drift: Tween

# Taxa de giro do input (para detectar curvas abertas)
var giro_input := 0.0
var _dir_input_anterior := Vector3.ZERO

# Partes que inclinam junto no drift, e suas poses originais
var _partes: Array[Node3D] = []
var _transforms_originais: Array[Transform3D] = []


func _ready():
	vida = vida_maxima

	_partes.assign([_model, collision_corpo, collision_tampa, area_atropelamento])
	for parte in _partes:
		_transforms_originais.append(parte.transform)

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
	cooldown_drift = maxf(cooldown_drift - delta, 0.0)
	tempo_cooldown_dash = maxf(tempo_cooldown_dash - delta, 0.0)

	# INPUT
	var raw_input := Input.get_vector("Andar_Esquerda", "Andar_Direita", "Andar_Frente", "Andar_Tras")
	var move_direction := _direcao_de_movimento(raw_input)
	var tem_input := move_direction != Vector3.ZERO

	_atualizar_giro_input(move_direction, tem_input, delta)
	_atualizar_dash(move_direction, tem_input, delta)

	var velocidade_atual := _velocidade_atual()

	# DRIFT: verifica se deve começar
	if not em_drift:
		_checar_inicio_drift(move_direction, tem_input, delta)

	# MOVIMENTO
	if em_drift:
		_atualizar_drift(move_direction, tem_input, velocidade_atual, delta)

	if not em_drift:
		velocity = velocity.move_toward(move_direction * velocidade_atual, acceleration * delta)

	move_and_slide()
	verificar_colisao_quebravel()

	_atualizar_rotacao(move_direction, tem_input, delta)
	atualizar_camera(delta)
	atualizar_fumaca_drift()

	if em_dash:
		verificar_atropelamento()


# =========================================================
# INPUT / MOVIMENTO
# =========================================================

func _direcao_de_movimento(raw_input: Vector2) -> Vector3:
	# Movimento relativo à câmera
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	forward.y = 0.0
	right.y = 0.0

	var direcao := forward.normalized() * raw_input.y + right.normalized() * raw_input.x
	direcao.y = 0.0

	if direcao.length_squared() > 0.01:
		return direcao.normalized()

	return Vector3.ZERO


func _atualizar_giro_input(move_direction: Vector3, tem_input: bool, delta: float) -> void:
	# Taxa de giro (rad/s, suavizada) da direção desejada.
	# Girar a câmera segurando W (ou W+A / W+D) faz essa taxa aumentar.
	var giro_instantaneo := 0.0

	if tem_input and _dir_input_anterior != Vector3.ZERO:
		giro_instantaneo = _dir_input_anterior.signed_angle_to(move_direction, Vector3.UP) / delta

	giro_input = lerpf(giro_input, giro_instantaneo, 1.0 - exp(-SUAVIZACAO_GIRO_INPUT * delta))
	_dir_input_anterior = move_direction


func _velocidade_atual() -> float:
	if em_dash:
		return velocidade_dash

	if preparando_dash:
		return move_speed * velocidade_preparacao

	return move_speed


func _atualizar_rotacao(move_direction: Vector3, tem_input: bool, delta: float) -> void:
	if not tem_input:
		return

	var rotacao_alvo := atan2(move_direction.x, move_direction.z)
	var velocidade_rotacao := rotation_speed

	# Durante o drift o corpo gira mais rápido e um pouco além, apontando para dentro da curva
	if em_drift:
		rotacao_alvo += lado_drift * deg_to_rad(angulo_derrapagem)
		velocidade_rotacao *= multiplicador_rotacao_drift

	rotation.y = lerp_angle(rotation.y, rotacao_alvo, velocidade_rotacao * delta)


# =========================================================
# CAMERA
# =========================================================

func atualizar_camera(delta: float):
	_camera_pivot.global_position = global_position

	# Mouse esq/dir (gira mais rápido durante o drift)
	if _camera_input_x != 0.0:
		var multiplicador := multiplicador_camera_drift if em_drift else 1.0
		_camera_pivot.rotation.y -= _camera_input_x * delta * multiplicador
		_camera_input_x = 0.0

	# FOV abre durante o drift
	var fov_alvo := _fov_base + (fov_extra_drift if em_drift else 0.0)
	_camera.fov = lerpf(_camera.fov, fov_alvo, 1.0 - exp(-4.0 * delta))

	# Inclina a câmera seguindo o drift
	var inclinacao_alvo := deg_to_rad(inclinacao_camera_drift) * lado_drift if em_drift else 0.0

	_camera_pivot.rotation.z = lerp_angle(
		_camera_pivot.rotation.z,
		inclinacao_alvo,
		1.0 - exp(-velocidade_inclinacao_camera * delta)
	)


# =========================================================
# DASH
# =========================================================

func _atualizar_dash(move_direction: Vector3, tem_input: bool, delta: float) -> void:
	if Input.is_action_just_pressed("Dash"):
		comecar_preparacao_dash(move_direction)

	if preparando_dash:
		tempo_preparacao -= delta

		if tem_input:
			direcao_dash = move_direction

		if tempo_preparacao <= 0.0:
			comecar_dash(move_direction)

	if em_dash:
		tempo_dash -= delta

		if tempo_dash <= 0.0:
			terminar_dash()


func comecar_preparacao_dash(move_direction: Vector3):
	if preparando_dash or em_dash or tempo_cooldown_dash > 0.0:
		return

	preparando_dash = true
	tempo_preparacao = tempo_preparacao_dash

	if move_direction != Vector3.ZERO:
		direcao_dash = move_direction
	else:
		direcao_dash = global_basis.z.normalized()


func comecar_dash(move_direction: Vector3):
	preparando_dash = false
	em_dash = true

	tempo_preparacao = 0.0
	tempo_dash = duracao_dash

	if move_direction != Vector3.ZERO:
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

func _checar_inicio_drift(move_direction: Vector3, tem_input: bool, delta: float) -> void:
	var vel_h := Vector3(velocity.x, 0.0, velocity.z)
	var quer_drift := false

	if tem_input and cooldown_drift <= 0.0 \
			and vel_h.length_squared() >= velocidade_minima_drift * velocidade_minima_drift:
		var angulo := vel_h.angle_to(move_direction)

		# Curva fechada: ângulo grande de uma vez
		var curva_fechada := angulo >= deg_to_rad(angulo_drift)
		# Curva aberta: o input está girando rápido e já existe um ângulo razoável
		var curva_aberta := absf(giro_input) >= giro_minimo_drift \
				and angulo >= deg_to_rad(angulo_minimo_curva_aberta)

		quer_drift = curva_fechada or curva_aberta

	# A condição precisa se manter por um tempinho (filtra toques rápidos)
	if quer_drift:
		_tempo_intencao_drift += delta
	else:
		_tempo_intencao_drift = 0.0

	if _tempo_intencao_drift >= tempo_confirmar_inicio_drift:
		comecar_drift(vel_h.normalized(), move_direction)


func _atualizar_drift(move_direction: Vector3, tem_input: bool, velocidade_atual: float, delta: float) -> void:
	tempo_em_drift += delta

	# Soltou as teclas: encerra o drift.
	if not tem_input:
		terminar_drift()
		return

	var vel_h := Vector3(velocity.x, 0.0, velocity.z)
	var velocidade_escalar := vel_h.length()
	var direcao_atual := vel_h / velocidade_escalar if velocidade_escalar > 0.01 else move_direction

	var angulo_restante := direcao_atual.signed_angle_to(move_direction, Vector3.UP)

	# Se o jogador inverteu a curva (esq <-> dir), troca o lado do drift
	var novo_lado := lado_drift
	if absf(angulo_restante) > deg_to_rad(angulo_troca_lado_drift):
		novo_lado = -signf(angulo_restante)
	elif absf(giro_input) >= giro_minimo_drift:
		novo_lado = -signf(giro_input)

	if novo_lado != lado_drift:
		trocar_lado_drift(novo_lado, move_direction)

	# Giro adaptativo: quanto mais falta pra alinhar, mais rápido gira
	var giro := clampf(
		absf(angulo_restante) * ganho_giro_drift,
		velocidade_giro_drift,
		velocidade_giro_maximo_drift
	)
	# Derrapagem: menos aderência = a velocidade demora mais a virar
	giro *= fator_derrapagem
	# Inércia no começo: mantém o embalo na direção antiga e só depois começa a curvar
	giro *= clampf(tempo_em_drift / maxf(tempo_inercia_drift, 0.001), 0.0, 1.0)

	var passo := clampf(angulo_restante, -giro * delta, giro * delta)
	var nova_direcao := direcao_atual.rotated(Vector3.UP, passo)

	# Perde velocidade durante o drift (não afeta o dash)
	var velocidade_alvo := velocidade_atual if em_dash else velocidade_atual * multiplicador_velocidade_drift
	velocidade_escalar = move_toward(velocidade_escalar, velocidade_alvo, desaceleracao_drift * delta)

	velocity.x = nova_direcao.x * velocidade_escalar
	velocity.z = nova_direcao.z * velocidade_escalar

	# Terminou a curva? Precisa estar alinhado E sem estar girando, por um tempinho
	var alinhado := absf(nova_direcao.signed_angle_to(move_direction, Vector3.UP)) <= deg_to_rad(angulo_fim_drift)
	var ainda_girando := absf(giro_input) >= giro_minimo_drift * 0.5

	if alinhado and not ainda_girando:
		_tempo_reto += delta
	else:
		_tempo_reto = 0.0

	var terminou := tempo_em_drift >= tempo_minimo_drift and _tempo_reto >= tempo_confirmar_fim_drift

	if terminou or tempo_em_drift >= duracao_maxima_drift:
		terminar_drift(terminou)


func comecar_drift(direcao_atual: Vector3, nova_direcao: Vector3):
	if em_drift:
		return

	em_drift = true
	tempo_em_drift = 0.0
	_tempo_reto = 0.0
	_tempo_intencao_drift = 0.0

	# Lado da inclinação: primeiro pelo ângulo da curva, depois pela taxa de giro do input
	var angulo_curva := direcao_atual.signed_angle_to(nova_direcao, Vector3.UP)

	if absf(angulo_curva) > deg_to_rad(5.0):
		lado_drift = -signf(angulo_curva)
	elif absf(giro_input) > 0.1:
		lado_drift = -signf(giro_input)

	_animar_pose(true, DURACAO_ENTRAR_DRIFT)
	driftou.emit(nova_direcao)


func trocar_lado_drift(novo_lado: float, nova_direcao: Vector3):
	lado_drift = novo_lado
	_tempo_reto = 0.0
	_animar_pose(true, DURACAO_TROCAR_LADO)
	driftou.emit(nova_direcao)


func terminar_drift(dar_boost: bool = false):
	if not em_drift:
		return

	# Saiu de um drift longo: ganha um impulso na direção que está indo
	if dar_boost and tempo_em_drift >= tempo_para_boost_drift:
		var vel_h := Vector3(velocity.x, 0.0, velocity.z)
		var velocidade := vel_h.length()

		if velocidade > 0.5:
			var com_impulso := vel_h / velocidade * (velocidade + impulso_boost_drift)
			velocity.x = com_impulso.x
			velocity.z = com_impulso.z
			boost_drift.emit()

	em_drift = false
	tempo_em_drift = 0.0
	_tempo_reto = 0.0
	cooldown_drift = tempo_entre_drifts

	_animar_pose(false, DURACAO_SAIR_DRIFT)


func _animar_pose(pose_drift: bool, duracao: float) -> void:
	# Leva modelo, colisões e área para a pose de drift (inclinada e elevada) ou de volta à original
	var rotacao_drift := Transform3D(Basis(Vector3.FORWARD, deg_to_rad(inclinacao_drift) * lado_drift), Vector3.ZERO)

	if _tween_drift and _tween_drift.is_valid():
		_tween_drift.kill()

	_tween_drift = create_tween()
	_tween_drift.set_parallel(true)

	for i in _partes.size():
		var alvo := _transforms_originais[i]

		if pose_drift:
			alvo = rotacao_drift * alvo
			alvo.origin.y += altura_drift

		_tween_drift.tween_property(_partes[i], "transform", alvo, duracao)


func atualizar_fumaca_drift():
	if particula_drift == null:
		return

	if not em_drift:
		if particula_drift.emitting:
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

	if not particula_drift.emitting:
		particula_drift.emitting = true


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
		var objeto = get_slide_collision(i).get_collider()

		if objeto.is_in_group("Quebravel"):
			objeto.queue_free()
