
extends CharacterBody3D

const GRUPO_ATROPELAVEL := &"atropelavel"

# ==========================================
# CONFIGURAÇÕES
# ==========================================

# MOVIMENTO
@export var velocidade: float = 1.3
@export var distancia_pulo: float = 1.0
@export var tempo_pulo: float = 0.5
@export var altura_pulo: float = 1.0

# EMPURRÃO DO CORTADOR
@export var forca_empurrao: float = 6.0
@export var desaceleracao_empurrao: float = 8.0

var impulso_empurrao: Vector3 = Vector3.ZERO

# DANO
@export var dano: float = 2.0
@export var intervalo_dano: float = 1.0

# ARREMESSO
@export var distancia_arremesso: float = 2.0
@export var altura_arremesso: float = 0.6
@export var velocidade_giro_arremesso: float = 8.0
@export var tempo_caido: float = 4.0

# SONS DE MOVIMENTO
@export var intervalo_som_passos: float = 1.5

# REFERÊNCIAS
@export var Cortador: CharacterBody3D
@export var ponto_destino: Marker3D

@onready var colisao: CollisionShape3D = $CollisionShape3D

# ==========================================
# ESTADOS
# ==========================================

enum Estado {
	PERSEGUINDO,
	PULANDO,
	PRESO,
	CAIDO,
	ARREMESSADO,
	MORTO
}

var estado: Estado = Estado.PERSEGUINDO
var causando_dano: bool = false
var pai_original: Node

var _distancia_pulo_quad: float = 0.0
var _inicio_pulo: Vector3 = Vector3.ZERO
var _tempo_pulo_atual: float = 0.0
var _tempo_arremesso: float = 0.0

var _timer_dano: Timer
var _timer_caido: Timer
var _timer_som_passos: Timer


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:
	pai_original = get_parent()
	_distancia_pulo_quad = distancia_pulo * distancia_pulo

	_timer_dano = Timer.new()
	_timer_dano.wait_time = intervalo_dano
	_timer_dano.one_shot = false
	_timer_dano.timeout.connect(_tick_dano)
	add_child(_timer_dano)

	_timer_caido = Timer.new()
	_timer_caido.wait_time = tempo_caido
	_timer_caido.one_shot = true
	_timer_caido.timeout.connect(_acabou_tempo_caido)
	add_child(_timer_caido)

	_timer_som_passos = Timer.new()
	_timer_som_passos.wait_time = intervalo_som_passos
	_timer_som_passos.one_shot = false
	_timer_som_passos.timeout.connect(_tocar_som_passos)
	add_child(_timer_som_passos)

	_timer_som_passos.start()

	set_process(false)

	if is_instance_valid(Cortador):
		Cortador.driftou.connect(_quando_driftar)


# ==========================================
# PROCESSAMENTO FÍSICO
# ==========================================

func _physics_process(delta: float) -> void:
	match estado:
		Estado.PERSEGUINDO:
			_perseguir(delta)

		Estado.ARREMESSADO:
			_atualizar_arremesso(delta)


# ==========================================
# SOM DO GNOMO ANDANDO
# ==========================================

func _tocar_som_passos() -> void:
	if estado != Estado.PERSEGUINDO:
		return

	if Vector2(velocity.x, velocity.z).length_squared() < 0.01:
		return

	# AUDIO: GnomoSons
	# Toca periodicamente enquanto anda.

	# $GnomoSons.play()


# ==========================================
# SISTEMA DE EMPURRÃO
# ==========================================

func receber_empurrao(direcao: Vector3) -> void:
	# Só pode ser empurrado enquanto está em pé.
	if estado != Estado.PERSEGUINDO:
		return

	direcao.y = 0.0

	if direcao.length_squared() < 0.001:
		return

	impulso_empurrao = direcao.normalized() * forca_empurrao


# ==========================================
# PERSEGUIÇÃO
# ==========================================

func _perseguir(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if not is_instance_valid(Cortador):
		velocity.x = impulso_empurrao.x
		velocity.z = impulso_empurrao.z

		impulso_empurrao = impulso_empurrao.move_toward(
			Vector3.ZERO,
			desaceleracao_empurrao * delta
		)

		move_and_slide()
		return

	var diferenca := Cortador.global_position - global_position
	diferenca.y = 0.0

	var distancia_quadrada := diferenca.length_squared()

	# Só pula quando a vaga estiver livre.
	# Não inicia o pulo enquanto está sendo empurrado.
	if distancia_quadrada <= _distancia_pulo_quad and is_on_floor():
		if impulso_empurrao.length_squared() < 0.1:
			if not is_instance_valid(Cortador.gnomo_em_cima):
				comecar_pulo()
				return

	# Continua perseguindo mesmo com outro gnomo em cima.
	var direcao := Vector3.ZERO

	if distancia_quadrada > 0.0001:
		direcao = diferenca.normalized()

	# Movimento normal + empurrão.
	velocity.x = direcao.x * velocidade + impulso_empurrao.x
	velocity.z = direcao.z * velocidade + impulso_empurrao.z

	# Reduz o empurrão gradualmente.
	impulso_empurrao = impulso_empurrao.move_toward(
		Vector3.ZERO,
		desaceleracao_empurrao * delta
	)

	move_and_slide()

	# ANIMAÇÃO: GnomoAndando
	# if $AnimationPlayer.current_animation != "GnomoAndando":
	#     $AnimationPlayer.play("GnomoAndando")

	if direcao.length_squared() > 0.001:
		rotation.y = atan2(direcao.x, direcao.z) + PI / 2.0


# ==========================================
# PULO
# ==========================================

func comecar_pulo() -> void:
	if estado != Estado.PERSEGUINDO:
		return

	if not is_instance_valid(Cortador):
		return

	if not is_instance_valid(ponto_destino):
		return

	if is_instance_valid(Cortador.gnomo_em_cima):
		return

	# Reserva a vaga imediatamente.
	Cortador.gnomo_em_cima = self

	estado = Estado.PULANDO
	velocity = Vector3.ZERO
	impulso_empurrao = Vector3.ZERO

	# ANIMAÇÃO: PARAR GnomoAndando
	# $AnimationPlayer.stop()

	_inicio_pulo = global_position
	_tempo_pulo_atual = 0.0

	_timer_som_passos.stop()

	set_process(true)


func _process(delta: float) -> void:
	if estado != Estado.PULANDO:
		set_process(false)
		return

	if not is_instance_valid(Cortador) or not is_instance_valid(ponto_destino):
		liberar_vaga()
		estado = Estado.PERSEGUINDO
		_timer_som_passos.start()
		set_process(false)
		return

	_tempo_pulo_atual += delta

	var progresso := clampf(
		_tempo_pulo_atual / maxf(tempo_pulo, 0.001),
		0.0,
		1.0
	)

	var nova_posicao := _inicio_pulo.lerp(
		ponto_destino.global_position,
		progresso
	)

	nova_posicao.y += sin(progresso * PI) * altura_pulo

	global_position = nova_posicao

	if progresso >= 1.0:
		set_process(false)
		ficar_no_cortador()


# ==========================================
# PRESO NO CORTADOR
# ==========================================

func ficar_no_cortador() -> void:
	if estado != Estado.PULANDO:
		return

	estado = Estado.PRESO
	velocity = Vector3.ZERO
	impulso_empurrao = Vector3.ZERO

	colisao.set_deferred("disabled", true)

	# Prende o gnomo no Marker.
	reparent(ponto_destino, true)
	position = Vector3.ZERO

	set_physics_process(false)

	causando_dano = true

	# PARTICULA: ParticulaRoubandoGasolina
	# $ParticulaRoubandoGasolina.emitting = true

	dano_continuo()


# ==========================================
# DANO
# ==========================================

func dano_continuo() -> void:
	_tick_dano()

	if causando_dano and estado == Estado.PRESO:
		_timer_dano.start()


func _tick_dano() -> void:
	if not causando_dano or estado != Estado.PRESO:
		_timer_dano.stop()
		return

	if not is_instance_valid(Cortador):
		_timer_dano.stop()
		return

	Cortador.tomar_dano(dano)


# ==========================================
# DRIFT
# ==========================================

func _quando_driftar(direcao_drift: Vector3) -> void:
	if estado != Estado.PRESO:
		return

	cair_do_cortador(direcao_drift)


# ==========================================
# ARREMESSO
# ==========================================

func cair_do_cortador(direcao_drift: Vector3) -> void:
	if estado != Estado.PRESO:
		return

	estado = Estado.ARREMESSADO
	causando_dano = false
	_timer_dano.stop()

	# PARTICULA: ParticulaRoubandoGasolina
	# $ParticulaRoubandoGasolina.emitting = false

	var posicao_atual := global_position

	liberar_vaga()

	reparent(pai_original, true)
	global_position = posicao_atual

	# Reativa a colisão física.
	colisao.set_deferred("disabled", false)

	rotation.x = 0.0
	rotation.z = 0.0

	var lado := Vector3(
		-direcao_drift.z,
		0.0,
		direcao_drift.x
	)

	if lado.length_squared() > 0.0001:
		lado = lado.normalized()
	else:
		lado = Vector3.RIGHT

	var g := maxf(get_gravity().length(), 0.01)
	var v0 := sqrt(2.0 * g * altura_arremesso)
	var tempo_voo := maxf(2.0 * v0 / g, 0.05)

	velocity = lado * (distancia_arremesso / tempo_voo)
	velocity.y = v0

	_tempo_arremesso = 0.0

	set_physics_process(true)


func _atualizar_arremesso(delta: float) -> void:
	_tempo_arremesso += delta

	velocity += get_gravity() * delta

	# Faz o gnomo girar durante o voo.
	rotation.x += velocidade_giro_arremesso * delta

	move_and_slide()

	if _tempo_arremesso > 0.1 and is_on_floor():
		ficar_caido()


# ==========================================
# CAÍDO
# ==========================================

func ficar_caido() -> void:
	if estado != Estado.ARREMESSADO:
		return

	estado = Estado.CAIDO
	velocity = Vector3.ZERO
	impulso_empurrao = Vector3.ZERO

	rotation.x = deg_to_rad(90.0)
	rotation.z = 0.0

	move_and_collide(Vector3.DOWN * 0.2)

	set_physics_process(false)

	# Agora pode ser atropelado.
	if not is_in_group(GRUPO_ATROPELAVEL):
		add_to_group(GRUPO_ATROPELAVEL)

	_timer_caido.start()


func _acabou_tempo_caido() -> void:
	if estado == Estado.CAIDO:
		levantar()


# ==========================================
# LEVANTAR
# ==========================================

func levantar() -> void:
	if estado != Estado.CAIDO:
		return

	_timer_caido.stop()

	if is_in_group(GRUPO_ATROPELAVEL):
		remove_from_group(GRUPO_ATROPELAVEL)

	rotation.x = 0.0
	rotation.z = 0.0

	estado = Estado.PERSEGUINDO
	velocity = Vector3.ZERO
	impulso_empurrao = Vector3.ZERO

	_timer_som_passos.start()

	set_physics_process(true)


# ==========================================
# CONTROLE DA VAGA
# ==========================================

func liberar_vaga() -> void:
	if not is_instance_valid(Cortador):
		return

	if Cortador.gnomo_em_cima == self:
		Cortador.gnomo_em_cima = null


# ==========================================
# MORTE POR ATROPELAMENTO
# ==========================================

func morrer_atropelado() -> void:
	# Só morre quando está caído.
	if estado != Estado.CAIDO:
		return

	GameManager.adicionar_pontos(50, global_position)
	GameManager.registrar_gnomo()

	estado = Estado.MORTO
	causando_dano = false

	_timer_dano.stop()
	_timer_caido.stop()
	_timer_som_passos.stop()

	if is_in_group(GRUPO_ATROPELAVEL):
		remove_from_group(GRUPO_ATROPELAVEL)

	liberar_vaga()

	# ANIMAÇÃO: PARAR GnomoAndando
	# $AnimationPlayer.stop()

	# AUDIO: GnomoMorte
	# $GnomoMorte.play()

	# PARTICULA: ParticulaMorte
	# $ParticulaMorte.emitting = true

	# Desaparece imediatamente.
	hide()

	colisao.set_deferred("disabled", true)

	set_physics_process(false)
	set_process(false)

	await get_tree().create_timer(1.0).timeout
	queue_free()
