extends CharacterBody3D

# ==========================================
# SOM DO MOTOR
# ==========================================

@export_group("Som do Motor")
@export var ativar_som_motor: bool = true
@export var motor_em_loop: bool = true
@export_range(-40.0, 10.0, 1.0) var volume_motor_db: float = 0.0
@export_range(0.5, 2.0, 0.05) var pitch_motor: float = 1.0

@onready var som_motor: Node = find_child("Motor", true, false)

@export_group("Fade do Motor")
@export_range(0.1, 5.0, 0.1) var tempo_fade_motor: float = 1.0

var volume_atual_motor: float = 0.0

var estava_andando: bool = false

var gnomo_em_cima: CharacterBody3D = null

signal gasolina_alterada(atual, maximo)
signal morreu
signal driftou(direcao: Vector3)
signal boost_drift

var esta_morto: bool = false

const ACAO_ESQUERDA := &"Andar_Esquerda"
const ACAO_DIREITA := &"Andar_Direita"
const ACAO_FRENTE := &"Andar_Frente"
const ACAO_TRAS := &"Andar_Tras"
const GRUPO_QUEBRAVEL := &"Quebravel"
const GRUPO_ATROPELAVEL := &"atropelavel"

const SUAVIZACAO_GIRO_INPUT := 12.0
const DURACAO_ENTRAR_DRIFT := 0.15
const DURACAO_TROCAR_LADO := 0.6
const DURACAO_SAIR_DRIFT := 0.25
const LIMIAR_EMISSAO_GASOLINA := 0.2

# ==========================================
# PARTÍCULAS
# ==========================================

@onready var particula_fumaca_preta: GPUParticles3D = find_child("fumassa preta carrinho", true, false) as GPUParticles3D
@onready var particula_gotas_gasolina: GPUParticles3D = find_child("gotas gasolina", true, false) as GPUParticles3D
@onready var particula_grama_cortada: GPUParticles3D = find_child("grama sendo cortada 2", true, false) as GPUParticles3D
@onready var particula_drift: GPUParticles3D = find_child("ParticulaDrift", true, false) as GPUParticles3D

# ==========================================
# REFERÊNCIAS
# ==========================================

@onready var area_atropelamento: Area3D = $AreaAtropelamento
@onready var collision_corpo: CollisionShape3D = $CollisionShape3D
@onready var collision_tampa: CollisionShape3D = $CollisionShape3D2
@onready var _model: Node3D = $Node3D
@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D
@onready var marker_esq: Node3D = find_child("Esq", true, false)
@onready var marker_dir: Node3D = find_child("Dir", true, false)

# ==========================================
# GASOLINA
# ==========================================

@export_group("Gasolina")
@export var gasolina_maxima: float = 100.0
@export var consumo_gasolina: float = 1.0

# ==========================================
# MOVIMENTO
# ==========================================

@export_group("Movement")
@export var move_speed: float = 4.0
@export var acceleration: float = 4.7
@export var rotation_speed: float = 2.5

@export_group("Marcha Ré")
@export var velocidade_re: float = 4.0
@export var aceleracao_re: float = 4.7
@export var velocidade_giro_re: float = 2.5

var dando_re: bool = false

# ==========================================
# PARTÍCULAS DE GRAMA
# ==========================================

@export_group("Partículas de Grama")
@export var sistema_grama: SistemaGrama
@export var sistema_chao: StaticBody3D
@export var distancia_verificacao_grama: float = 0.35

# ==========================================
# CÂMERA
# ==========================================

@export_group("Camera")
@export var limite_travar_camera: float = -0.3
@export var suavizacao_posicao_camera: float = 10.0
@export var suavizacao_giro_camera: float = 4.0
@export var multiplicador_camera_drift: float = 1.3
@export var inclinacao_camera_drift: float = 5.0
@export var velocidade_inclinacao_camera: float = 4.0
@export var fov_extra_drift: float = 6.0

@export_group("Camera - Colisão")
@export_flags_3d_physics var camera_colisao_mask: int = 2
@export var camera_margem: float = 0.3
@export var camera_retorno: float = 8.0

# ==========================================
# DRIFT - INÍCIO
# ==========================================

@export_group("Drift - Início")
@export var velocidade_minima_drift: float = 2.5
@export var angulo_drift: float = 45.0
@export var giro_minimo_drift: float = 1.8
@export var angulo_minimo_curva_aberta: float = 10.0
@export var tempo_confirmar_inicio_drift: float = 0.1
@export var tempo_entre_drifts: float = 0.65

# ==========================================
# DRIFT - FIM
# ==========================================

@export_group("Drift - Fim")
@export var angulo_fim_drift: float = 25.0
@export var tempo_confirmar_fim_drift: float = 0.3
@export var tempo_minimo_drift: float = 0.5
@export var duracao_maxima_drift: float = 2.0
@export var angulo_troca_lado_drift: float = 30.0

# ==========================================
# DRIFT - COMPORTAMENTO
# ==========================================

@export_group("Drift - Comportamento")
@export var velocidade_giro_drift: float = 2.5
@export var velocidade_giro_maximo_drift: float = 6.0
@export var ganho_giro_drift: float = 3.0
@export_range(0.15, 1.0) var fator_derrapagem: float = 0.25
@export var tempo_inercia_drift: float = 0.45
@export var multiplicador_rotacao_drift: float = 2.0
@export var angulo_derrapagem: float = 35.0
@export_range(0.3, 1.0) var multiplicador_velocidade_drift: float = 0.75
@export var desaceleracao_drift: float = 3.5

# ==========================================
# DRIFT - VISUAL
# ==========================================

@export_group("Drift - Visual e Boost")
@export var inclinacao_drift: float = 14.0
@export var altura_drift: float = 0.15
@export var inverter_lado_fumaca: bool = false
@export var tempo_para_boost_drift: float = 0.6
@export var impulso_boost_drift: float = 2.0

@export_group("Drift - Rotação Partículas")
@export var rotacao_particula_esquerda: Vector3 = Vector3.ZERO
@export var rotacao_particula_direita: Vector3 = Vector3(0, 180, 0)

# ==========================================
# VARIÁVEIS INTERNAS
# ==========================================

var gasolina: float
var _gasolina_emitida: float

var _fov_base := 75.0
var _offset_yaw_camera := 0.0
var _heading := 0.0
var _origem_braco := Vector3.ZERO
var _offset_camera := Vector3.ZERO
var _fator_camera := 1.0
var _fator_suave := 1.0
var _fator_aplicado := 1.0
var _cam_z_plano := Vector3.ZERO

var _consulta: PhysicsRayQueryParameters3D
var _mundo: World3D

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

# ==========================================
# READY
# ==========================================

func _ready() -> void:
	gasolina = gasolina_maxima
	_gasolina_emitida = gasolina
	gasolina_alterada.emit(gasolina, gasolina_maxima)

	_partes.assign([_model, collision_corpo, collision_tampa, area_atropelamento])
	for parte in _partes:
		_transforms_originais.append(parte.transform)

	if particula_fumaca_preta:
		particula_fumaca_preta.emitting = false

	if particula_gotas_gasolina:
		particula_gotas_gasolina.emitting = false
		particula_gotas_gasolina.one_shot = true

	if particula_grama_cortada:
		particula_grama_cortada.emitting = false
		particula_grama_cortada.one_shot = false

	if particula_drift:
		particula_drift.emitting = false

	_fov_base = _camera.fov
	_heading = rotation.y
	area_atropelamento.body_entered.connect(_matar_se_atropelavel)

	var braco := _camera.get_parent() as SpringArm3D
	var pose_inicial := _camera_pivot.global_transform
	var basis_limpa := pose_inicial.basis.orthonormalized()
	var basis_inv := basis_limpa.inverse()

	var b_braco := braco.global_basis
	var pos_camera := braco.global_position + b_braco.orthonormalized().z * (braco.spring_length * b_braco.get_scale().z)
	_origem_braco = basis_inv * (braco.global_position - pose_inicial.origin)
	_offset_camera = basis_inv * (pos_camera - pose_inicial.origin)
	var basis_camera := basis_inv * _camera.global_basis.orthonormalized()

	_offset_yaw_camera = basis_limpa.get_euler().y - rotation.y
	_camera_pivot.top_level = true
	_camera_pivot.global_transform = Transform3D(basis_limpa, pose_inicial.origin)

	_camera.reparent(_camera_pivot)
	braco.queue_free()
	_camera.transform = Transform3D(basis_camera, _offset_camera)

	_mundo = get_world_3d()
	_consulta = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, camera_colisao_mask, [get_rid()])

# ==========================================
# PHYSICS PROCESS
# ==========================================

func _physics_process(delta: float) -> void:
	cooldown_drift = maxf(cooldown_drift - delta, 0.0)

	var raw_input := Input.get_vector(ACAO_ESQUERDA, ACAO_DIREITA, ACAO_FRENTE, ACAO_TRAS)
	dando_re = Input.is_action_pressed(ACAO_TRAS) and not Input.is_action_pressed(ACAO_FRENTE)

	if dando_re and gasolina > 0.0:
		if em_drift:
			terminar_drift()

		_tempo_intencao_drift = 0.0
		var esterco := Input.get_axis(ACAO_ESQUERDA, ACAO_DIREITA)
		rotation.y += esterco * velocidade_giro_re * delta

	var dir := _direcao_de_movimento(raw_input)

	if gasolina <= 0.0:
		dir = Vector3.ZERO

	var tem_input := dir != Vector3.ZERO
	atualizar_som_motor(tem_input, delta)
	# VERIFICA A MÁSCARA ANTES DE ATIVAR A PARTÍCULA
	if particula_grama_cortada:
		var cortando_grama := tem_input and is_on_floor() and not esta_morto

		if cortando_grama:
			cortando_grama = verificar_grama_para_particula()

		particula_grama_cortada.emitting = cortando_grama

	_atualizar_gasolina(tem_input, delta)

	for objeto in area_atropelamento.get_overlapping_bodies():
		if objeto == self:
			continue
		_empurrar_gnomo(objeto)

	if gasolina <= 0.0:
		if particula_grama_cortada:
			particula_grama_cortada.emitting = false
		return

	if dando_re:
		var velocidade_atual := Vector2(velocity.x, velocity.z).length()
		velocidade_atual = move_toward(velocidade_atual, velocidade_re, aceleracao_re * delta)
		velocity.x = dir.x * velocidade_atual
		velocity.z = dir.z * velocidade_atual
	else:
		_atualizar_giro_input(dir, tem_input, delta)
		var vel_max := move_speed

		if not em_drift:
			_checar_inicio_drift(dir, tem_input, delta)

		if em_drift:
			_atualizar_drift(dir, tem_input, vel_max, delta)
		else:
			var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(dir * vel_max, acceleration * delta)
			velocity.x = horizontal.x
			velocity.z = horizontal.z

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta

	move_and_slide()
	verificar_colisao_quebravel()

	if not dando_re:
		_atualizar_rotacao(dir, tem_input, delta)

	_atualizar_colisao_camera()

func _process(delta: float) -> void:
	atualizar_camera(delta)
	atualizar_fumaca_drift()

# ==========================================
# VERIFICAR GRAMA PELA MÁSCARA
# ==========================================

func verificar_grama_para_particula() -> bool:
	var posicao := global_position
	var direcao := Vector3(velocity.x, 0.0, velocity.z)

	if direcao.length_squared() > 0.01:
		posicao += direcao.normalized() * distancia_verificacao_grama

	var existe_grama := false

	if is_instance_valid(sistema_grama) and sistema_grama.mascara != null:
		existe_grama = sistema_grama.tem_grama_na_posicao(posicao)

	if not existe_grama and is_instance_valid(sistema_chao):
		if sistema_chao.has_method("tem_grama_na_posicao"):
			existe_grama = sistema_chao.tem_grama_na_posicao(posicao)

	return existe_grama

# ==========================================
# DIREÇÃO
# ==========================================

func _direcao_de_movimento(raw_input: Vector2) -> Vector3:
	if raw_input == Vector2.ZERO:
		return Vector3.ZERO

	if dando_re:
		var tras := -global_basis.z
		tras.y = 0.0
		return tras.normalized()

	var cam_basis := _camera.global_basis
	var frente := cam_basis.z
	var direita := cam_basis.x

	frente.y = 0.0
	direita.y = 0.0
	_cam_z_plano = frente.normalized()

	var dir := _cam_z_plano * raw_input.y + direita.normalized() * raw_input.x
	dir.y = 0.0

	return dir.normalized() if dir.length_squared() > 0.01 else Vector3.ZERO

func _atualizar_giro_input(dir: Vector3, tem_input: bool, delta: float) -> void:
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

	var indo_para_tras := dir.dot(-_cam_z_plano) < limite_travar_camera

	if not indo_para_tras:
		_heading = lerp_angle(_heading, alvo, vel * delta)

	rotation.y = lerp_angle(rotation.y, alvo + desvio, vel * delta)

# ==========================================
# CÂMERA
# ==========================================

func atualizar_camera(delta: float) -> void:
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

# ==========================================
# DRIFT
# ==========================================

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

	var angulo_curva := direcao_atual.signed_angle_to(nova_direcao, Vector3.UP)

	if absf(angulo_curva) > deg_to_rad(5.0):
		lado_drift = -signf(angulo_curva)
	elif absf(giro_input) > 0.1:
		lado_drift = -signf(giro_input)

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

	var giro := clampf(absf(restante) * ganho_giro_drift, velocidade_giro_drift, velocidade_giro_maximo_drift)
	giro *= fator_derrapagem
	giro *= clampf(tempo_em_drift / maxf(tempo_inercia_drift, 0.001), 0.0, 1.0)

	var passo := clampf(restante, -giro * delta, giro * delta)
	var nova := atual.rotated(Vector3.UP, passo)

	var alvo := vel_max * multiplicador_velocidade_drift
	vel = move_toward(vel, alvo, desaceleracao_drift * delta)
	velocity.x = nova.x * vel
	velocity.z = nova.z * vel

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
	if not em_drift or particula_drift == null:
		return

	var esquerda := (lado_drift > 0.0) != inverter_lado_fumaca
	var marker := marker_esq if esquerda else marker_dir

	if marker:
		particula_drift.global_transform = marker.global_transform
		particula_drift.global_basis = marker.global_basis * Basis.from_euler(
			Vector3(
				deg_to_rad(rotacao_particula_esquerda.x if esquerda else rotacao_particula_direita.x),
				deg_to_rad(rotacao_particula_esquerda.y if esquerda else rotacao_particula_direita.y),
				deg_to_rad(rotacao_particula_esquerda.z if esquerda else rotacao_particula_direita.z)
			)
		)

# ==========================================
# COLISÕES
# ==========================================

func _matar_se_atropelavel(objeto: Node3D) -> void:
	if objeto.is_in_group(GRUPO_ATROPELAVEL) and objeto.has_method("morrer_atropelado"):
		objeto.morrer_atropelado()

func verificar_colisao_quebravel() -> void:
	for objeto in area_atropelamento.get_overlapping_areas():
		if objeto.is_in_group(GRUPO_QUEBRAVEL):
			Quebravel.quebrar(objeto)

# ==========================================
# DANO NA GASOLINA
# ==========================================

func tomar_dano(dano: float) -> void:
	if gasolina <= 0.0 or esta_morto:
		return

	var dano_real := maxf(dano, 0.0)

	if dano_real <= 0.0:
		return

	print("========== DANO RECEBIDO ==========")
	print("GASOLINA ANTES: ", gasolina)
	print("DANO: ", dano_real)

	gasolina = clampf(gasolina - dano_real, 0.0, gasolina_maxima)

	print("GASOLINA DEPOIS: ", gasolina)
	print("===================================")

	# REINICIA A RAJADA A CADA ATAQUE
	if particula_gotas_gasolina:
		particula_gotas_gasolina.restart()
		particula_gotas_gasolina.emitting = true

	_emitir_gasolina()

	if gasolina <= 0.0:
		morrer()

# ==========================================
# MORTE
# ==========================================

func morrer() -> void:
	if gasolina > 0.0 or esta_morto:
		return

	esta_morto = true
	
	if som_motor:
		som_motor.stop()

	if particula_fumaca_preta:
		particula_fumaca_preta.emitting = false

	if particula_grama_cortada:
		particula_grama_cortada.emitting = false

	if particula_gotas_gasolina:
		particula_gotas_gasolina.emitting = false

	if particula_drift:
		particula_drift.emitting = false

	# SOM MORTE
	# som_motor.stop()
	# som_morte.play()

	# PARTÍCULAS MORTE
	# particulas_morte.restart()
	# particulas_morte.emitting = true

	morreu.emit()
	hide()

	set_physics_process(false)
	set_process(false)

	collision_corpo.set_deferred("disabled", true)
	collision_tampa.set_deferred("disabled", true)

	area_atropelamento.set_deferred("monitoring", false)
	area_atropelamento.set_deferred("monitorable", false)

	get_tree().call_deferred("change_scene_to_file", "res://Cenas/CenaGameOver.tscn")

# ==========================================
# GASOLINA
# ==========================================

func reabastecer(quantidade: float) -> void:
	gasolina = minf(gasolina + quantidade, gasolina_maxima)
	_emitir_gasolina()

func _atualizar_gasolina(tem_input: bool, delta: float) -> void:
	if esta_morto:
		return

	if tem_input:
		gasolina = maxf(gasolina - consumo_gasolina * delta, 0.0)
		_emitir_gasolina()

		if gasolina <= 0.0:
			morrer()
			return

func _emitir_gasolina() -> void:
	atualizar_fumaca_preta()

	var mudou := absf(gasolina - _gasolina_emitida) >= LIMIAR_EMISSAO_GASOLINA
	var chegou_no_limite := (gasolina <= 0.0 or gasolina >= gasolina_maxima) and gasolina != _gasolina_emitida

	if mudou or chegou_no_limite:
		_gasolina_emitida = gasolina
		gasolina_alterada.emit(gasolina, gasolina_maxima)


func _empurrar_gnomo(objeto: Node3D) -> void:
	if not is_instance_valid(objeto):
		return

	if not objeto.has_method("receber_empurrao"):
		return

	var direcao: Vector3 = objeto.global_position - global_position
	direcao.y = 0.0

	if direcao.length_squared() < 0.0001:
		direcao = -global_transform.basis.z
		direcao.y = 0.0

	objeto.receber_empurrao(direcao.normalized())


func atualizar_fumaca_preta() -> void:
	if particula_fumaca_preta == null:
		return

	if gasolina_maxima <= 0.0:
		particula_fumaca_preta.emitting = false
		return

	var porcentagem_vida := gasolina / gasolina_maxima
	particula_fumaca_preta.emitting = porcentagem_vida < 0.4 and not esta_morto
	
func atualizar_som_motor(tem_input: bool, delta: float) -> void:
	if som_motor == null:
		return

	if not som_motor is AudioStreamPlayer and not som_motor is AudioStreamPlayer3D:
		return

	if som_motor.stream == null:
		return

	var andando := tem_input and gasolina > 0.0 and not esta_morto and ativar_som_motor

	som_motor.pitch_scale = pitch_motor

	if som_motor.stream is AudioStreamWAV:
		som_motor.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if motor_em_loop else AudioStreamWAV.LOOP_DISABLED
	elif som_motor.stream is AudioStreamOggVorbis:
		som_motor.stream.loop = motor_em_loop
	elif som_motor.stream is AudioStreamMP3:
		som_motor.stream.loop = motor_em_loop

	# COMEÇOU A ANDAR
	if andando and not estava_andando:
		volume_atual_motor = 1.0
		som_motor.volume_db = volume_motor_db
		som_motor.play()

	# DIMINUI O VOLUME GRADUALMENTE AO PARAR
	if not andando:
		volume_atual_motor = move_toward(
			volume_atual_motor,
			0.0,
			delta / maxf(tempo_fade_motor, 0.01)
		)

		if volume_atual_motor <= 0.0:
			if som_motor.playing:
				som_motor.stop()
		else:
			som_motor.volume_db = volume_motor_db + linear_to_db(volume_atual_motor)

	# ENQUANTO ANDA
	else:
		volume_atual_motor = 1.0
		som_motor.volume_db = volume_motor_db

		if motor_em_loop and not som_motor.playing:
			som_motor.play()

	estava_andando = andando
