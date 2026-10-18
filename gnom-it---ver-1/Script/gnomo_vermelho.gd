extends CharacterBody3D

# ==========================================
# CONFIGURAÇÕES
# ==========================================

# GRAVIDADE
var gravidade: float = 9.8

# DANO
@export var dano: float = 5
var sendo_atropelado: bool = false

# VELOCIDADE
@export var velocidade: float = 3.5
@export var velocidade_ataque: float = 3.0
@export var velocidade_inicial: float = 0.5
@export var aceleracao: float = 1.5

var velocidade_atual: float = 0.0
var velocidade_rotacao = 2.0

# CORTADOR
@export var Cortador: CharacterBody3D

# DISTÂNCIA
var distancia_cercar = 0.6
var forca_recuo = 0.6

# TEMPO
var tempo_parado = 0.5

# SONS ALEATÓRIOS
@export var intervalo_som_min: float = 1.0
@export var intervalo_som_max: float = 3.0
@export var pitch_som_min: float = 0.8
@export var pitch_som_max: float = 1.4

# ESTADOS
var atacando = false
var parado = false

# POSIÇÃO DO INIMIGO NO CÍRCULO
var indice_inimigo = 0
var quantidade_inimigos = 1

# TIMER DOS SONS
var _timer_som: Timer


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready():
	velocidade_atual = velocidade_inicial
	atualizar_grupo()

	# Timer para sons aleatórios.
	_timer_som = Timer.new()
	_timer_som.one_shot = true
	_timer_som.timeout.connect(_tocar_som_perseguicao)
	add_child(_timer_som)


# ==========================================
# SOM ALEATÓRIO DURANTE A PERSEGUIÇÃO
# ==========================================

func _agendar_som_perseguicao() -> void:
	if sendo_atropelado or parado or atacando:
		return

	var intervalo = randf_range(
		intervalo_som_min,
		intervalo_som_max
	)

	_timer_som.start(maxf(intervalo, 0.01))


func _tocar_som_perseguicao() -> void:
	if sendo_atropelado or parado or atacando:
		return

	# ======================================
	# AUDIO: GnomoSons
	# Toca aleatoriamente enquanto persegue.
	# Pitch também varia aleatoriamente.
	# ======================================

	# $GnomoSons.pitch_scale = randf_range(
	#     pitch_som_min,
	#     pitch_som_max
	# )
	# $GnomoSons.play()

	# Agenda o próximo som.
	# _agendar_som_perseguicao()


# ==========================================
# ATUALIZAR GRUPO
# ==========================================

func atualizar_grupo():
	var inimigos = get_tree().get_nodes_in_group("inimigos")

	indice_inimigo = inimigos.find(self)
	quantidade_inimigos = max(inimigos.size(), 1)


# ==========================================
# PROCESSAMENTO FÍSICO
# ==========================================

func _physics_process(delta):
	if not is_instance_valid(Cortador):
		return

	# GRAVIDADE
	if not is_on_floor():
		velocity.y -= gravidade * delta
	else:
		velocity.y = 0.0

	if parado:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# ACELERAÇÃO PROGRESSIVA
	var velocidade_maxima = velocidade_ataque if atacando else velocidade

	velocidade_atual = move_toward(
		velocidade_atual,
		velocidade_maxima,
		aceleracao * delta
	)

	# Distância horizontal até o cortador
	var diferenca_cortador = Cortador.global_position - global_position
	diferenca_cortador.y = 0.0

	var distancia_quadrada = diferenca_cortador.length_squared()

	# Começa o ataque
	if distancia_quadrada <= distancia_cercar * distancia_cercar:
		if not atacando:
			atacando = true

			# ======================================
			# ANIMAÇÃO: GnomoAtacando
			# Toca quando começa a atacar.
			# ======================================

			# $AnimationPlayer.play("GnomoAtacando")

			# Para os sons de perseguição.
			# _timer_som.stop()

	var destino: Vector3

	if atacando:
		destino = Cortador.global_position
	else:
		var angulo = (TAU / quantidade_inimigos) * indice_inimigo
		var offset = Vector3(cos(angulo), 0.0, sin(angulo)) * distancia_cercar
		destino = Cortador.global_position + offset

	# Direção
	var direcao = destino - global_position
	direcao.y = 0.0

	var comprimento_quadrado = direcao.length_squared()

	if comprimento_quadrado > 0.0001:
		direcao /= sqrt(comprimento_quadrado)

		velocity.x = direcao.x * velocidade_atual
		velocity.z = direcao.z * velocidade_atual

		move_and_slide()

		# Rotação
		var angulo_desejado = atan2(direcao.x, direcao.z)
		rotation.y = lerp_angle(
			rotation.y,
			angulo_desejado + PI / 2,
			velocidade_rotacao * delta
		)

		if not atacando:
			# ======================================
			# ANIMAÇÃO: GnomoAndando
			# Toca enquanto persegue o jogador.
			# Não reinicia a cada frame.
			# ======================================

			# if $AnimationPlayer.current_animation != "GnomoAndando":
			#     $AnimationPlayer.play("GnomoAndando")

			# ======================================
			# AUDIO: GnomoSons
			# Inicia sons aleatórios ao perseguir.
			# ======================================

			# if _timer_som.is_stopped():
			#     _agendar_som_perseguicao()

			pass

		else:
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()

		# ======================================
		# ANIMAÇÃO: PARAR GnomoAndando
		# ======================================

		# if not atacando:
		#     $AnimationPlayer.stop()

		# Cancela os sons se parar de andar.
		# _timer_som.stop()

		pass

	# Verifica colisão durante o ataque
	if atacando:
		for i in get_slide_collision_count():
			var colisao = get_slide_collision(i)

			if colisao.get_collider() == Cortador:
				ataque_acertou()
				break


# ==========================================
# ATAQUE
# ==========================================

func ataque_acertou():
	if sendo_atropelado:
		return

	atacando = false
	parado = true

	# ======================================
	# ANIMAÇÃO: PARAR GnomoAtacando
	# Para a animação ao acertar o jogador.
	# ======================================

	# $AnimationPlayer.stop()

	# Para os sons durante o recuo.
	# _timer_som.stop()

	Cortador.tomar_dano(dano)

	var direcao_recuo = global_position - Cortador.global_position
	direcao_recuo.y = 0.0

	if direcao_recuo.length_squared() > 0.0001:
		direcao_recuo = direcao_recuo.normalized()
		global_position += direcao_recuo * forca_recuo

	velocity = Vector3.ZERO

	# Reinicia aceleração depois do ataque
	velocidade_atual = velocidade_inicial

	await get_tree().create_timer(tempo_parado).timeout

	if is_inside_tree():
		parado = false


# ==========================================
# MORTE POR ATROPELAMENTO
# ==========================================

func morrer_atropelado():
	if sendo_atropelado:
		return
	
	GameManager.adicionar_pontos(50, global_position)
	GameManager.registrar_gnomo()
	
	sendo_atropelado = true
	atacando = false
	parado = true
	velocity = Vector3.ZERO

	# ======================================
	# ANIMAÇÃO: PARAR TODAS
	# ======================================

	# $AnimationPlayer.stop()

	# ======================================
	# AUDIO: PARAR GnomoSons
	# ======================================

	# _timer_som.stop()
	# $GnomoSons.stop()

	# ======================================
	# AUDIO: GnomoMorte
	# Toca quando o gnomo morre.
	# ======================================

	# $GnomoMorte.play()

	# ======================================
	# PARTICULA: GnomoMorte
	# Emite partículas quando morre.
	# ======================================

	# $ParticulaGnomoMorte.emitting = true

	# Som original mantido.
	$AudioStreamPlayer/Morreu.play()

	set_physics_process(false)
	set_process(false)

	hide()

	collision_layer = 0
	collision_mask = 0

	await get_tree().create_timer(1.0).timeout
	queue_free()
