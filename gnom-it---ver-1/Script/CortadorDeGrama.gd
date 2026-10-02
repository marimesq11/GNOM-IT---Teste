extends CharacterBody3D

signal gasolina_alterada(atual, maximo)
signal dash_disponivel_alterado(disponivel: bool)
signal vida_alterada(vida_atual, vida_max)
signal morreu
signal driftou(direcao: Vector3)
signal boost_drift

# StringName evita converter String -> StringName a cada frame
const ACAO_ESQUERDA := &"Andar_Esquerda"
const ACAO_DIREITA := &"Andar_Direita"
const ACAO_FRENTE := &"Andar_Frente"
const ACAO_TRAS := &"Andar_Tras"
const ACAO_DASH := &"Dash"
const GRUPO_QUEBRAVEL := &"Quebravel"
const GRUPO_ATROPELAVEL := &"atropelavel"

const SUAVIZACAO_GIRO_INPUT := 12.0
const DURACAO_ENTRAR_DRIFT := 0.15
const DURACAO_TROCAR_LADO := 0.6
const DURACAO_SAIR_DRIFT := 0.25
## A barra de gasolina só é avisada quando muda pelo menos isso (evita emit todo frame).
const LIMIAR_EMISSAO_GASOLINA := 0.2

@onready var particula_dash: GPUParticles3D = $ParticulaDash
@onready var area_atropelamento: Area3D = $AreaAtropelamento
@onready var collision_corpo: CollisionShape3D = $CollisionShape3D
@onready var collision_tampa: CollisionShape3D = $CollisionShape3D2
@onready var _model: Node3D = $Node3D
@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D
@onready var particula_drift: GPUParticles3D = find_child("ParticulaDrift", true, false)
@onready var marker_esq: Node3D = find_child("Esq", true, false)
@onready var marker_dir: Node3D = find_child("Dir", true, false)

@export_group("Gasolina")
@export var gasolina_maxima: float = 100.0
@export var consumo_gasolina: float = 0.5

@export_group("Vida")
@export var vida_maxima: float = 100.0

@export_group("Movement")
@export var move_speed: float = 4.5
@export var acceleration: float = 5.5
@export var rotation_speed: float = 3.0

@export_group("Camera")
## Abaixo desse valor (produto escalar com a frente da câmera) a câmera trava.
## -1.0 = só trava andando 100% para trás; 0.0 = trava também nas laterais.
@export var limite_travar_camera: float = -0.3
## Quão colada a câmera fica na posição do jogador. Maior = mais rígida.
@export var suavizacao_posicao_camera: float = 10.0
## Quão rápido a câmera gira para acompanhar o jogador. Menor = curva mais lenta.
@export var suavizacao_giro_camera: float = 4.0
## Multiplicador da velocidade de giro da câmera durante o drift.
@export var multiplicador_camera_drift: float = 1.3
@export var inclinacao_camera_drift: float = 5.0
@export var velocidade_inclinacao_camera: float = 4.0
## Quanto o FOV aumenta durante o drift (graus).
@export var fov_extra_drift: float = 6.0

@export_group("Camera - Colisão")
## Layers que barram a câmera (paredes/cenário). Não marque a layer dos inimigos.
@export_flags_3d_physics var camera_colisao_mask: int = 2
## Folga entre a câmera e a parede (em unidades do mundo).
@export var camera_margem: float = 0.3
## Velocidade com que a câmera volta ao normal depois de passar por um obstáculo.
@export var camera_retorno: float = 8.0

@export_group("Dash")
@export var velocidade_dash: float = 6.5
@export var tempo_preparacao_dash: float = 0.5
@export var duracao_dash: float = 0.5
@export var cooldown_dash: float = 2
@export var velocidade_preparacao: float = 0.85
## Quantas vezes o consumo aumenta durante o dash.
@export var multiplicador_consumo_dash: float = 3.0

@export_group("Drift - Início")
@export var velocidade_minima_drift: float = 2.5
## Curva fechada: ângulo (graus) entre velocidade e input para começar.
@export var angulo_drift: float = 45.0
## Curva aberta: quão rápido o input precisa girar (rad/s).
@export var giro_minimo_drift: float = 1.8
## Curva aberta: ângulo mínimo (graus) entre velocidade e input.
@export var angulo_minimo_curva_aberta: float = 10.0
## Tempo que a condição precisa se manter antes de começar (filtra toques rápidos).
@export var tempo_confirmar_inicio_drift: float = 0.1
## Espera depois de um drift para poder driftar de novo.
@export var tempo_entre_drifts: float = 0.65

@export_group("Drift - Fim")
## Ângulo (graus) abaixo do qual a curva é considerada terminada.
@export var angulo_fim_drift: float = 25.0
## Tempo que precisa estar "reto" para o drift terminar.
@export var tempo_confirmar_fim_drift: float = 0.3
@export var tempo_minimo_drift: float = 0.5
## Tempo máximo do drift (segurança).
@export var duracao_maxima_drift: float = 2.0
## Ângulo (graus) a partir do qual inverter a curva troca o lado do drift.
@export var angulo_troca_lado_drift: float = 30.0

@export_group("Drift - Comportamento")
## Giro MÍNIMO da direção durante o drift (rad/s).
@export var velocidade_giro_drift: float = 2.5
## Giro MÁXIMO (rad/s), usado quando falta muito ângulo.
@export var velocidade_giro_maximo_drift: float = 6.0
## Quanto o giro acelera conforme o ângulo restante.
@export var ganho_giro_drift: float = 3.0
## Aderência da curva. 1.0 = normal; menor = derrapa mais.
@export_range(0.15, 1.0) var fator_derrapagem: float = 0.25
## Tempo no começo do drift em que mantém o embalo antes de curvar.
@export var tempo_inercia_drift: float = 0.45
## Quanto o corpo gira mais rápido durante o drift.
@export var multiplicador_rotacao_drift: float = 2.0
## Ângulo extra (graus) que o corpo gira para dentro da curva.
@export var angulo_derrapagem: float = 35.0
## Velocidade no drift em relação à normal. Não afeta o dash.
@export_range(0.3, 1.0) var multiplicador_velocidade_drift: float = 0.75
@export var desaceleracao_drift: float = 3.5

@export_group("Drift - Visual e Boost")
@export var inclinacao_drift: float = 14.0
@export var altura_drift: float = 0.15
@export var inverter_lado_fumaca: bool = false
@export var tempo_para_boost_drift: float = 0.6
@export var impulso_boost_drift: float = 2.0

var gasolina: float
var vida: float

var _gasolina_emitida: float
var _dash_disponivel_antes := true

var _fov_base := 75.0
var _offset_yaw_camera := 0.0
var _heading := 0.0
var _origem_braco := Vector3.ZERO
var _offset_camera := Vector3.ZERO
var _fator_camera := 1.0
var _fator_suave := 1.0
var _fator_aplicado := 1.0
var _cam_z_plano := Vector3.ZERO  # "frente" horizontal da câmera, calculada 1x por frame

# Raycast da câmera reaproveitado (não cria objeto novo a cada frame)
var _consulta: PhysicsRayQueryParameters3D
var _mundo: World3D

var preparando_dash := false
var em_dash := false
var tempo_preparacao := 0.0
var tempo_dash := 0.0
var tempo_cooldown_dash := 0.0
var direcao_dash := Vector3.ZERO

var em_drift := false
var tempo_em_drift := 0.0
var cooldown_drift := 0.0
var lado_drift := 1.0
var _tempo_reto := 0.0
var _tempo_intencao_drift := 0.0
var _tween_drift: Tween

var giro_input := 0.0
var _dir_input_anterior := Vector3.ZERO

var _partes: Array[Node3D] = []
var _transforms_originais: Array[Transform3D] = []


func _ready() -> void:
	gasolina = gasolina_maxima
	_gasolina_emitida = gasolina
	gasolina_alterada.emit(gasolina, gasolina_maxima)
	vida = vida_maxima
	_partes.assign([_model, collision_corpo, collision_tampa, area_atropelamento])
	for parte in _partes:
		_transforms_originais.append(parte.transform)

	if particula_drift:
		particula_drift.emitting = false

	_fov_base = _camera.fov
	_heading = rotation.y
	vida_alterada.emit(vida, vida_maxima)
	area_atropelamento.body_entered.connect(_matar_se_atropelavel)

	# CÂMERA: substitui o SpringArm3D por um raycast próprio, que não depende da escala dos nós.
	var braco := _camera.get_parent() as SpringArm3D
	var pose_inicial := _camera_pivot.global_transform
	var basis_limpa := pose_inicial.basis.orthonormalized()
	var basis_inv := basis_limpa.inverse()

	# Guarda onde a câmera ficava (em unidades reais do mundo, relativas ao pivô)
	var b_braco := braco.global_basis
	var pos_camera := braco.global_position + b_braco.orthonormalized().z * (braco.spring_length * b_braco.get_scale().z)
	_origem_braco = basis_inv * (braco.global_position - pose_inicial.origin)
	_offset_camera = basis_inv * (pos_camera - pose_inicial.origin)
	var basis_camera := basis_inv * _camera.global_basis.orthonormalized()

	_offset_yaw_camera = basis_limpa.get_euler().y - rotation.y
	_camera_pivot.top_level = true
	_camera_pivot.global_transform = Transform3D(basis_limpa, pose_inicial.origin)

	# A câmera sai do SpringArm e passa a ser filha direta do pivô (escala 1)
	_camera.reparent(_camera_pivot)
	braco.queue_free()
	_camera.transform = Transform3D(basis_camera, _offset_camera)

	# Raycast criado uma única vez e só atualizado a cada frame
	_mundo = get_world_3d()
	_consulta = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, camera_colisao_mask, [get_rid()])


func _physics_process(delta: float) -> void:
	cooldown_drift = maxf(cooldown_drift - delta, 0.0)
	tempo_cooldown_dash = maxf(tempo_cooldown_dash - delta, 0.0)

	var raw_input := Input.get_vector(ACAO_ESQUERDA, ACAO_DIREITA, ACAO_FRENTE, ACAO_TRAS)
	var dir := _direcao_de_movimento(raw_input)
	if gasolina <= 0.0:
		dir = Vector3.ZERO  # sem gasolina, não anda
	var tem_input := dir != Vector3.ZERO

	_atualizar_gasolina(tem_input, delta)
	_atualizar_giro_input(dir, tem_input, delta)
	_atualizar_dash(dir, tem_input, delta)

	var vel_max := velocidade_dash if em_dash else move_speed * (velocidade_preparacao if preparando_dash else 1.0)

	if not em_drift:
		_checar_inicio_drift(dir, tem_input, delta)

	if em_drift:
		_atualizar_drift(dir, tem_input, vel_max, delta)
	else:
		# Só X e Z, para não apagar a gravidade
		var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(dir * vel_max, acceleration * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z

	# Gravidade (vale em qualquer estado: parado, andando, dash e drift)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta

	move_and_slide()
	verificar_colisao_quebravel()
	_atualizar_rotacao(dir, tem_input, delta)
	_atualizar_colisao_camera()


func _process(delta: float) -> void:
	atualizar_camera(delta)
	atualizar_fumaca_drift()


# ---------------------------------------------------------
# INPUT / MOVIMENTO / CÂMERA
# ---------------------------------------------------------

func _direcao_de_movimento(raw_input: Vector2) -> Vector3:
	# Sem input: nem lê a transform da câmera
	if raw_input == Vector2.ZERO:
		return Vector3.ZERO

	var cam_basis := _camera.global_basis  # lido 1x e reaproveitado em _atualizar_rotacao
	var frente := cam_basis.z
	var direita := cam_basis.x
	frente.y = 0.0
	direita.y = 0.0
	_cam_z_plano = frente.normalized()
	var dir := _cam_z_plano * raw_input.y + direita.normalized() * raw_input.x
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.01 else Vector3.ZERO


func _atualizar_giro_input(dir: Vector3, tem_input: bool, delta: float) -> void:
	# Taxa de giro (rad/s, suavizada) da direção desejada, usada para detectar curvas abertas.
	var instantaneo := 0.0
	if tem_input and _dir_input_anterior != Vector3.ZERO:
		instantaneo = _dir_input_anterior.signed_angle_to(dir, Vector3.UP) / delta
	giro_input = lerpf(giro_input, instantaneo, 1.0 - exp(-SUAVIZACAO_GIRO_INPUT * delta))
	_dir_input_anterior = dir


func _atualizar_rotacao(dir: Vector3, tem_input: bool, delta: float) -> void:
	if not tem_input:
		return

	var alvo := atan2(dir.x, dir.z)
	var vel := rotation_speed * (multiplicador_rotacao_drift if em_drift else 1.0)
	var desvio := lado_drift * deg_to_rad(angulo_derrapagem) if em_drift else 0.0

	# Indo "para trás" em relação à câmera: trava a câmera (não atualiza o _heading)
	# frente da câmera = -z, e _cam_z_plano já é o z horizontal normalizado
	var indo_para_tras := dir.dot(-_cam_z_plano) < limite_travar_camera

	if not indo_para_tras:
		_heading = lerp_angle(_heading, alvo, vel * delta)

	rotation.y = lerp_angle(rotation.y, alvo + desvio, vel * delta)


func atualizar_camera(delta: float) -> void:
	# Só escreve na cena quando o valor realmente mudou (cada escrita marca transform/render como "sujo")
	var pos_pivo := _camera_pivot.global_position
	var pos_alvo := global_position
	if not pos_pivo.is_equal_approx(pos_alvo):
		_camera_pivot.global_position = pos_pivo.lerp(pos_alvo, 1.0 - exp(-suavizacao_posicao_camera * delta))

	var seguir := suavizacao_giro_camera * (multiplicador_camera_drift if em_drift else 1.0)
	var yaw_atual := _camera_pivot.rotation.y
	var yaw_alvo := _heading + _offset_yaw_camera
	if not is_equal_approx(angle_difference(yaw_atual, yaw_alvo), 0.0):
		_camera_pivot.rotation.y = lerp_angle(yaw_atual, yaw_alvo, 1.0 - exp(-seguir * delta))

	var fov_alvo := _fov_base + (fov_extra_drift if em_drift else 0.0)
	if not is_equal_approx(_camera.fov, fov_alvo):
		_camera.fov = lerpf(_camera.fov, fov_alvo, 1.0 - exp(-4.0 * delta))

	var inclinacao := deg_to_rad(inclinacao_camera_drift) * lado_drift if em_drift else 0.0
	var roll_atual := _camera_pivot.rotation.z
	if not is_equal_approx(angle_difference(roll_atual, inclinacao), 0.0):
		_camera_pivot.rotation.z = lerp_angle(roll_atual, inclinacao, 1.0 - exp(-velocidade_inclinacao_camera * delta))

	# Aproxima na hora quando há parede; volta suave quando o caminho libera
	if _fator_camera < _fator_suave:
		_fator_suave = _fator_camera
	elif is_equal_approx(_fator_suave, _fator_camera):
		_fator_suave = _fator_camera
	else:
		_fator_suave = lerpf(_fator_suave, _fator_camera, 1.0 - exp(-camera_retorno * delta))

	if _fator_suave != _fator_aplicado:
		_fator_aplicado = _fator_suave
		_camera.position = _origem_braco + (_offset_camera - _origem_braco) * _fator_suave


func _atualizar_colisao_camera() -> void:
	# Raio do "ombro" do jogador até a posição ideal da câmera (usa a mesma query de sempre)
	var t := _camera_pivot.global_transform
	var origem := t * _origem_braco
	var destino := t * _offset_camera

	_consulta.from = origem
	_consulta.to = destino
	var acerto := _mundo.direct_space_state.intersect_ray(_consulta)

	if acerto:
		var total := origem.distance_to(destino)
		_fator_camera = clampf((origem.distance_to(acerto.position) - camera_margem) / total, 0.0, 1.0)
	else:
		_fator_camera = 1.0


# ---------------------------------------------------------
# DASH
# ---------------------------------------------------------

func _atualizar_dash(dir: Vector3, tem_input: bool, delta: float) -> void:
	if Input.is_action_just_pressed(ACAO_DASH) and _dash_disponivel():
		preparando_dash = true
		tempo_preparacao = tempo_preparacao_dash
		direcao_dash = dir if tem_input else global_basis.z.normalized()

	if preparando_dash:
		tempo_preparacao -= delta
		if tem_input:
			direcao_dash = dir

		if tempo_preparacao <= 0.0:
			preparando_dash = false
			em_dash = true
			tempo_dash = duracao_dash
			particula_dash.emitting = true
			particula_dash.restart()

	elif em_dash:
		tempo_dash -= delta

		if tempo_dash <= 0.0:
			em_dash = false
			tempo_cooldown_dash = cooldown_dash
			particula_dash.emitting = false


# ---------------------------------------------------------
# DRIFT
# ---------------------------------------------------------

func _checar_inicio_drift(dir: Vector3, tem_input: bool, delta: float) -> void:
	var quer_drift := false

	if tem_input and cooldown_drift <= 0.0:
		var vel_h := Vector3(velocity.x, 0.0, velocity.z)
		if vel_h.length_squared() >= velocidade_minima_drift * velocidade_minima_drift:
			var angulo := vel_h.angle_to(dir)
			var curva_fechada := angulo >= deg_to_rad(angulo_drift)
			var curva_aberta := absf(giro_input) >= giro_minimo_drift and angulo >= deg_to_rad(angulo_minimo_curva_aberta)
			quer_drift = curva_fechada or curva_aberta

	_tempo_intencao_drift = _tempo_intencao_drift + delta if quer_drift else 0.0

	if _tempo_intencao_drift >= tempo_confirmar_inicio_drift:
		comecar_drift(Vector3(velocity.x, 0.0, velocity.z).normalized(), dir)


func comecar_drift(direcao_atual: Vector3, nova_direcao: Vector3) -> void:
	em_drift = true
	tempo_em_drift = 0.0
	_tempo_reto = 0.0
	_tempo_intencao_drift = 0.0

	# Lado da inclinação: pelo ângulo da curva, senão pela taxa de giro do input
	var angulo_curva := direcao_atual.signed_angle_to(nova_direcao, Vector3.UP)
	if absf(angulo_curva) > deg_to_rad(5.0):
		lado_drift = -signf(angulo_curva)
	elif absf(giro_input) > 0.1:
		lado_drift = -signf(giro_input)

	# A fumaça liga/desliga aqui, só nas mudanças de estado (não precisa checar todo frame)
	if particula_drift:
		particula_drift.emitting = true

	_animar_pose(true, DURACAO_ENTRAR_DRIFT)
	driftou.emit(nova_direcao)


func _atualizar_drift(dir: Vector3, tem_input: bool, vel_max: float, delta: float) -> void:
	tempo_em_drift += delta

	if not tem_input:
		terminar_drift()
		return

	var vel_h := Vector3(velocity.x, 0.0, velocity.z)
	var vel := vel_h.length()
	var atual := vel_h / vel if vel > 0.01 else dir
	var restante := atual.signed_angle_to(dir, Vector3.UP)

	# Inverteu a curva (esq <-> dir): troca o lado do drift
	var novo_lado := lado_drift
	if absf(restante) > deg_to_rad(angulo_troca_lado_drift):
		novo_lado = -signf(restante)
	elif absf(giro_input) >= giro_minimo_drift:
		novo_lado = -signf(giro_input)

	if novo_lado != lado_drift:
		lado_drift = novo_lado
		_tempo_reto = 0.0
		_animar_pose(true, DURACAO_TROCAR_LADO)
		driftou.emit(dir)

	# Giro adaptativo, com derrapagem e inércia no começo
	var giro := clampf(absf(restante) * ganho_giro_drift, velocidade_giro_drift, velocidade_giro_maximo_drift)
	giro *= fator_derrapagem
	giro *= clampf(tempo_em_drift / maxf(tempo_inercia_drift, 0.001), 0.0, 1.0)

	var passo := clampf(restante, -giro * delta, giro * delta)
	var nova := atual.rotated(Vector3.UP, passo)

	# Perde velocidade no drift (não afeta o dash)
	var alvo := vel_max if em_dash else vel_max * multiplicador_velocidade_drift
	vel = move_toward(vel, alvo, desaceleracao_drift * delta)
	velocity.x = nova.x * vel
	velocity.z = nova.z * vel

	# Terminou a curva? Alinhado e sem girar, por um tempinho
	var alinhado := absf(nova.signed_angle_to(dir, Vector3.UP)) <= deg_to_rad(angulo_fim_drift)
	var ainda_girando := absf(giro_input) >= giro_minimo_drift * 0.5
	_tempo_reto = _tempo_reto + delta if (alinhado and not ainda_girando) else 0.0

	var terminou := tempo_em_drift >= tempo_minimo_drift and _tempo_reto >= tempo_confirmar_fim_drift
	if terminou or tempo_em_drift >= duracao_maxima_drift:
		terminar_drift(terminou)


func terminar_drift(dar_boost: bool = false) -> void:
	if not em_drift:
		return

	if dar_boost and tempo_em_drift >= tempo_para_boost_drift:
		var vel_h := Vector3(velocity.x, 0.0, velocity.z)
		var vel := vel_h.length()

		if vel > 0.5:
			var novo := vel_h / vel * (vel + impulso_boost_drift)
			velocity.x = novo.x
			velocity.z = novo.z
			boost_drift.emit()

	em_drift = false
	tempo_em_drift = 0.0
	_tempo_reto = 0.0
	cooldown_drift = tempo_entre_drifts
	if particula_drift:
		particula_drift.emitting = false
	_animar_pose(false, DURACAO_SAIR_DRIFT)


func _animar_pose(pose_drift: bool, duracao: float) -> void:
	# Leva modelo, colisões e área para a pose de drift (inclinada e elevada) ou de volta à original
	var rotacao_drift := Transform3D(Basis(Vector3.FORWARD, deg_to_rad(inclinacao_drift) * lado_drift), Vector3.ZERO)

	if _tween_drift and _tween_drift.is_valid():
		_tween_drift.kill()

	_tween_drift = create_tween().set_parallel(true)

	for i in _partes.size():
		var alvo := _transforms_originais[i]
		if pose_drift:
			alvo = rotacao_drift * alvo
			alvo.origin.y += altura_drift
		_tween_drift.tween_property(_partes[i], "transform", alvo, duracao)


func atualizar_fumaca_drift() -> void:
	# Fora do drift não faz nada (o emitting já é ligado/desligado em comecar/terminar_drift)
	if not em_drift or particula_drift == null:
		return

	# lado_drift > 0 = esquerda -> marker Esq
	var esquerda := (lado_drift > 0.0) != inverter_lado_fumaca
	var marker := marker_esq if esquerda else marker_dir

	if marker:
		particula_drift.global_transform = marker.global_transform


# ---------------------------------------------------------
# ATROPELAMENTO / COLISÕES
# ---------------------------------------------------------

func _matar_se_atropelavel(body: Node) -> void:
	if body.is_in_group(GRUPO_ATROPELAVEL) and body.has_method(&"morrer_atropelado"):
		body.morrer_atropelado()


func verificar_colisao_quebravel() -> void:
	for i in get_slide_collision_count():
		var objeto := get_slide_collision(i).get_collider() as Node
		if objeto == null:
			continue

		if objeto.is_in_group(GRUPO_QUEBRAVEL):
			Quebravel.quebrar(objeto)
		else:
			_matar_se_atropelavel(objeto)


# ---------------------------------------------------------
# VIDA
# ---------------------------------------------------------

func tomar_dano(dano: float) -> void:
	if vida <= 0.0:
		return

	vida = clampf(vida - dano, 0.0, vida_maxima)
	vida_alterada.emit(vida, vida_maxima)

	if vida <= 0.0:
		morrer()


func morrer() -> void:
	morreu.emit()
	hide()
	set_physics_process(false)
	set_process(false)
	collision_corpo.set_deferred("disabled", true)
	collision_tampa.set_deferred("disabled", true)
	area_atropelamento.set_deferred("monitoring", false)
	area_atropelamento.set_deferred("monitorable", false)


# ---------------------------------------------------------
# GASOLINA
# ---------------------------------------------------------

func reabastecer(quantidade: float) -> void:
	gasolina = minf(gasolina + quantidade, gasolina_maxima)
	_emitir_gasolina()


func _dash_disponivel() -> bool:
	return not preparando_dash and not em_dash and tempo_cooldown_dash <= 0.0 and gasolina > 0.0


func _atualizar_gasolina(tem_input: bool, delta: float) -> void:
	if tem_input:
		var consumo := consumo_gasolina * (multiplicador_consumo_dash if em_dash else 1.0)
		gasolina = maxf(gasolina - consumo * delta, 0.0)
		_emitir_gasolina()

	var disponivel := _dash_disponivel()
	if disponivel != _dash_disponivel_antes:
		_dash_disponivel_antes = disponivel
		dash_disponivel_alterado.emit(disponivel)


func _emitir_gasolina() -> void:
	# Só avisa a UI quando a diferença é visível (ou ao chegar em 0 / no máximo)
	var mudou := absf(gasolina - _gasolina_emitida) >= LIMIAR_EMISSAO_GASOLINA
	var chegou_no_limite := (gasolina <= 0.0 or gasolina >= gasolina_maxima) and gasolina != _gasolina_emitida
	if mudou or chegou_no_limite:
		_gasolina_emitida = gasolina
		gasolina_alterada.emit(gasolina, gasolina_maxima)
