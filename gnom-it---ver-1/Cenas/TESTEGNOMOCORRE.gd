extends CharacterBody3D

# ==========================================
# CONFIGURAÇÕES
# ==========================================

# MOVIMENTO
@export var velocidade_fuga: float = 2.7
@export var distancia_deteccao: float = 30
@export var distancia_parede: float = 4
@export var aceleracao: float = 12.0

# SONS ALEATÓRIOS
@export var intervalo_som_min: float = 1.0
@export var intervalo_som_max: float = 3.0
@export var pitch_som_min: float = 0.8
@export var pitch_som_max: float = 1.4

# ==========================================
# VARIÁVEIS
# ==========================================

var player: Node3D = null
var esta_morto: bool = false
var direcao_fuga := Vector3.ZERO

var _timer_som: Timer


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready():
	# ======================================
	# TIMER: GnomoSons
	# Controla intervalos aleatórios dos sons.
	# ======================================

	_timer_som = Timer.new()
	_timer_som.one_shot = true
	_timer_som.timeout.connect(_tocar_som_fuga)
	add_child(_timer_som)

	await get_tree().process_frame

	player = get_tree().get_first_node_in_group("player")

	if player:
		print("PLAYER ENCONTRADO: ", player.name)
	else:
		print("ERRO: PLAYER NÃO ENCONTRADO!")


# ==========================================
# PROCESSAMENTO FÍSICO
# ==========================================

func _physics_process(delta: float) -> void:
	if esta_morto or player == null:
		return

	var distancia = global_position.distance_to(player.global_position)

	if distancia <= distancia_deteccao:
		var direcao_player = player.global_position.direction_to(global_position)
		direcao_player.y = 0.0
		direcao_player = direcao_player.normalized()

		var espaco = verificar_parede(direcao_player)

		if espaco:
			direcao_fuga = direcao_player
		else:
			var esquerda = Vector3(-direcao_player.z, 0, direcao_player.x)
			var direita = Vector3(direcao_player.z, 0, -direcao_player.x)

			if pode_andar(esquerda):
				direcao_fuga = esquerda
			elif pode_andar(direita):
				direcao_fuga = direita
			else:
				direcao_fuga = direcao_player

	else:
		direcao_fuga = Vector3.ZERO

	var velocidade_desejada = direcao_fuga * velocidade_fuga

	velocity.x = move_toward(
		velocity.x,
		velocidade_desejada.x,
		aceleracao * delta
	)

	velocity.z = move_toward(
		velocity.z,
		velocidade_desejada.z,
		aceleracao * delta
	)

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	if direcao_fuga.length() > 0.1:
		var target_rotation = atan2(
			direcao_fuga.x,
			direcao_fuga.z
		)

		rotation.y = lerp_angle(
			rotation.y,
			target_rotation,
			10.0 * delta
		)

		# ======================================
		# ANIMAÇÃO: GnomoFugindo
		# Reproduz enquanto foge do jogador.
		# Não reinicia a cada frame.
		# ======================================

		# if $AnimationPlayer.current_animation != "GnomoFugindo":
		#     $AnimationPlayer.play("GnomoFugindo")

		# ======================================
		# AUDIO: GnomoSons
		# Inicia sons aleatórios durante a fuga.
		# ======================================

		# if _timer_som.is_stopped():
		#     _agendar_som_fuga()

	else:
		# ======================================
		# ANIMAÇÃO: PARAR GnomoFugindo
		# Para quando não está fugindo.
		# ======================================

		# if $AnimationPlayer.current_animation == "GnomoFugindo":
		#     $AnimationPlayer.stop()

		# ======================================
		# AUDIO: PARAR GnomoSons
		# Cancela sons quando para de fugir.
		# ======================================

		# _timer_som.stop()

		pass


# ==========================================
# SOM ALEATÓRIO DURANTE A FUGA
# ==========================================

func _agendar_som_fuga() -> void:
	if esta_morto:
		return

	var intervalo = randf_range(
		intervalo_som_min,
		intervalo_som_max
	)

	_timer_som.start(maxf(intervalo, 0.01))


func _tocar_som_fuga() -> void:
	if esta_morto:
		return

	if direcao_fuga.length() <= 0.1:
		return

	# ======================================
	# AUDIO: GnomoSons
	# Toca com pitch aleatório.
	# ======================================

	# $GnomoSons.pitch_scale = randf_range(
	#     pitch_som_min,
	#     pitch_som_max
	# )
	# $GnomoSons.play()

	# Agenda o próximo som aleatório.
	# _agendar_som_fuga()


# ==========================================
# VERIFICAR PAREDE
# ==========================================

func verificar_parede(direcao: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state

	var origem = global_position
	var destino = origem + direcao * distancia_parede

	var query = PhysicsRayQueryParameters3D.create(
		origem,
		destino
	)

	query.exclude = [self]

	var resultado = space_state.intersect_ray(query)

	return resultado.is_empty()


# ==========================================
# VERIFICAR DIREÇÃO LIVRE
# ==========================================

func pode_andar(direcao: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state

	var origem = global_position
	var destino = origem + direcao.normalized() * distancia_parede

	var query = PhysicsRayQueryParameters3D.create(
		origem,
		destino
	)

	query.exclude = [self]

	var resultado = space_state.intersect_ray(query)

	return resultado.is_empty()


# ==========================================
# MORTE POR ATROPELAMENTO
# ==========================================

func morrer_atropelado() -> void:
	if esta_morto:
		return

	esta_morto = true

	GameManager.adicionar_pontos(10, global_position)
	GameManager.registrar_gnomo()

	# ======================================
	# ANIMAÇÃO: PARAR GnomoFugindo
	# ======================================

	# $AnimationPlayer.stop()

	# ======================================
	# AUDIO: PARAR GnomoSons
	# ======================================

	# _timer_som.stop()
	# $GnomoSons.stop()

	# ======================================
	# AUDIO: GnomoMorrendo
	# Toca quando o gnomo morre.
	# ======================================

	# $GnomoMorrendo.play()

	# ======================================
	# PARTICULA: GnomoMorte
	# Emite partículas quando morre.
	# ======================================

	# $GnomoMorte.emitting = true

	hide()

	$CollisionShape3D.set_deferred("disabled", true)
	$Area3D/CollisionShape3D.set_deferred("disabled", true)

	# Som original mantido.
	$AudioStreamPlayer/Morreu.play()

	await get_tree().create_timer(1.0).timeout

	queue_free()
