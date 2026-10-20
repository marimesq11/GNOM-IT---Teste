
extends CharacterBody3D

# ==========================================
# CONFIGURAÇÕES
# ==========================================

# MOVIMENTO
@export var velocidade_fuga: float = 2.7
@export var distancia_deteccao: float = 30.0
@export var distancia_parede: float = 4.0
@export var aceleracao: float = 12.0

# SUSTO E PULO
@export var forca_pulo: float = 5.0
@export var gravidade: float = 9.8
@export var tempo_susto: float = 0.8

# SPRINT
@export var velocidade_sprint: float = 9.0
@export var duracao_sprint: float = 2.0

# POPUP DE EXCLAMAÇÃO
@export var cena_popup: PackedScene
@export var altura_popup: float = 2.0

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

# ESTADOS
var assustado: bool = false
var em_susto: bool = false
var em_sprint: bool = false
var sprint_finalizada: bool = false

var tempo_susto_atual: float = 0.0
var tempo_sprint_atual: float = 0.0

# Impede reiniciar a sprint
var aguardando_aterrissagem: bool = false


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:

	_timer_som = Timer.new()
	_timer_som.one_shot = true
	_timer_som.timeout.connect(_tocar_som_fuga)
	add_child(_timer_som)

	await get_tree().process_frame

	if esta_morto:
		return

	player = get_tree().get_first_node_in_group("player") as Node3D

	if player:
		print("PLAYER ENCONTRADO: ", player.name)
	else:
		print("ERRO: PLAYER NÃO ENCONTRADO!")


# ==========================================
# PROCESSAMENTO FÍSICO
# ==========================================

func _physics_process(delta: float) -> void:

	if esta_morto or not is_instance_valid(player):
		return

	var distancia = global_position.distance_to(
		player.global_position
	)

	# ======================================
	# DETECTAR JOGADOR
	# ======================================

	if distancia <= distancia_deteccao:

		if not assustado:
			iniciar_susto()

	else:

		# Só permite outro susto depois
		# que a sequência anterior terminar.
		if not em_susto and not em_sprint \
		and not aguardando_aterrissagem:

			assustado = false
			sprint_finalizada = false

	# ======================================
	# GRAVIDADE
	# ======================================

	if not is_on_floor():
		velocity.y -= gravidade * delta

	elif velocity.y < 0.0:
		velocity.y = 0.0

	# ======================================
	# SUSTO
	# ======================================

	if em_susto:

		tempo_susto_atual -= delta

		velocity.x = move_toward(
			velocity.x,
			0.0,
			aceleracao * delta
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			aceleracao * delta
		)

		# ANIMAÇÃO: GnomoBalançando
		# if $AnimationPlayer.current_animation != "GnomoBalançando":
		#     $AnimationPlayer.play("GnomoBalançando")

		if tempo_susto_atual <= 0.0:

			em_susto = false
			aguardando_aterrissagem = true

			# ANIMAÇÃO: PARAR GnomoBalançando
			# $AnimationPlayer.stop()

		move_and_slide()
		return

	# ======================================
	# AGUARDAR ATERRISSAGEM
	# ======================================

	if aguardando_aterrissagem:

		velocity.x = 0.0
		velocity.z = 0.0

		move_and_slide()

		if is_on_floor():

			aguardando_aterrissagem = false

			if not sprint_finalizada:
				iniciar_sprint()

		return

	# ======================================
	# CONTADOR DA SPRINT
	# ======================================

	if em_sprint:

		tempo_sprint_atual -= delta

		if tempo_sprint_atual <= 0.0:

			em_sprint = false
			sprint_finalizada = true
			tempo_sprint_atual = 0.0

			print("SPRINT FINALIZADA!")

	# ======================================
	# DIREÇÃO DE FUGA
	# ======================================

	if distancia <= distancia_deteccao or em_sprint:

		var direcao_player = (
			player.global_position.direction_to(
				global_position
			)
		)

		direcao_player.y = 0.0
		direcao_player = direcao_player.normalized()

		if verificar_parede(direcao_player):

			direcao_fuga = direcao_player

		else:

			var esquerda = Vector3(
				-direcao_player.z,
				0,
				direcao_player.x
			)

			var direita = Vector3(
				direcao_player.z,
				0,
				-direcao_player.x
			)

			if pode_andar(esquerda):
				direcao_fuga = esquerda

			elif pode_andar(direita):
				direcao_fuga = direita

			else:
				direcao_fuga = direcao_player

	else:
		direcao_fuga = Vector3.ZERO

	# ======================================
	# VELOCIDADE
	# ======================================

	var velocidade_atual: float = velocidade_fuga

	if em_sprint:
		velocidade_atual = velocidade_sprint

	var velocidade_desejada = (
		direcao_fuga * velocidade_atual
	)

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

	move_and_slide()

	# ======================================
	# ROTAÇÃO E ANIMAÇÃO
	# ======================================

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

		# ANIMAÇÃO: GnomoFugindo
		# if $AnimationPlayer.current_animation != "GnomoFugindo":
		#     $AnimationPlayer.play("GnomoFugindo")

		# AUDIO: GnomoSons
		# if _timer_som.is_stopped():
		#     _agendar_som_fuga()

	else:

		# ANIMAÇÃO: PARAR GnomoFugindo
		# if $AnimationPlayer.current_animation == "GnomoFugindo":
		#     $AnimationPlayer.stop()

		# AUDIO: PARAR GnomoSons
		# _timer_som.stop()

		pass


# ==========================================
# INICIAR SUSTO
# ==========================================

func iniciar_susto() -> void:

	if esta_morto or assustado:
		return

	assustado = true
	em_susto = true
	em_sprint = false
	sprint_finalizada = false
	aguardando_aterrissagem = false

	tempo_susto_atual = tempo_susto
	tempo_sprint_atual = 0.0

	velocity.x = 0.0
	velocity.z = 0.0

	# PULO
	velocity.y = forca_pulo

	print("GNOMO ASSUSTADO!")

	# ANIMAÇÃO: GnomoBalançando
	# $AnimationPlayer.play("GnomoBalançando")

	# AUDIO: PARAR GnomoSons
	# _timer_som.stop()

	criar_exclamacao()


# ==========================================
# INICIAR SPRINT
# ==========================================

func iniciar_sprint() -> void:

	if esta_morto or sprint_finalizada or em_sprint:
		return

	em_sprint = true
	tempo_sprint_atual = duracao_sprint

	print("GNOMO EM SPRINT!")

	# ANIMAÇÃO: GnomoFugindo
	# $AnimationPlayer.play("GnomoFugindo")


# ==========================================
# POPUP DE EXCLAMAÇÃO
# ==========================================

# ==========================================
# POPUP DE EXCLAMAÇÃO
# ==========================================

func criar_exclamacao() -> void:

	if cena_popup == null:
		print("ERRO: CENA POPUP NÃO CONFIGURADA!")
		return

	var popup = cena_popup.instantiate() as Label3D

	if popup == null:
		print("ERRO: POPUP NÃO É LABEL3D!")
		return

	get_tree().current_scene.add_child(popup)

	# POSIÇÃO ACIMA DO GNOMO
	popup.global_position = (
		global_position +
		Vector3(0, altura_popup, 0)
	)

	# CONFIGURAÇÃO DA EXCLAMAÇÃO
	popup.text = "!"
	popup.modulate = Color.YELLOW

	# USA A FUNÇÃO QUE VOCÊ JÁ TEM
	popup.aparecer("!")

	# ======================================
	# BALANÇO DA EXCLAMAÇÃO
	# ======================================

	var tween = create_tween()

	tween.tween_property(
		popup,
		"rotation:z",
		0.25,
		0.15
	)

	tween.tween_property(
		popup,
		"rotation:z",
		-0.25,
		0.15
	)

	tween.tween_property(
		popup,
		"rotation:z",
		0.25,
		0.15
	)

	tween.tween_property(
		popup,
		"rotation:z",
		-0.25,
		0.15
	)

	tween.tween_property(
		popup,
		"rotation:z",
		0.0,
		0.15
	)

	get_tree().current_scene.add_child(popup)

	popup.global_position = (
		global_position +
		Vector3(0, altura_popup, 0)
	)

	print("POPUP CRIADO: ", popup.name)

	# Procura uma Label3D dentro do popup
	var label = popup.find_child(
		"Label3D",
		true,
		false
	)

	if label is Label3D:

		label.text = "!"
		label.modulate = Color.YELLOW

	else:
		print("AVISO: Label3D não encontrada!")

	# ======================================
	# BALANÇO DO POPUP
	# ======================================

	var tween_balanco = create_tween()

	tween.tween_property(
		popup,
		"rotation:z",
		0.25,
		0.15
	)

	tween.tween_property(
		popup,
		"rotation:z",
		-0.25,
		0.15
	)

	tween.tween_property(
		popup,
		"rotation:z",
		0.25,
		0.15
	)

	tween.tween_property(
		popup,
		"rotation:z",
		0.0,
		0.15
	)

	# ======================================
	# SUBIR LENTAMENTE
	# ======================================

	var tween_subida = create_tween()

	tween_subida.tween_property(
		popup,
		"position:y",
		popup.position.y + 0.4,
		tempo_susto
	)

	# ======================================
	# REMOVER POPUP
	# ======================================

	get_tree().create_timer(
		tempo_susto
	).timeout.connect(
		func():
			if is_instance_valid(popup):
				popup.queue_free()
	)


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

	_timer_som.start(
		maxf(intervalo, 0.01)
	)


func _tocar_som_fuga() -> void:

	if esta_morto:
		return

	if direcao_fuga.length() <= 0.1:
		return

	# AUDIO: GnomoSons
	# $GnomoSons.pitch_scale = randf_range(
	#     pitch_som_min,
	#     pitch_som_max
	# )
	# $GnomoSons.play()

	# _agendar_som_fuga()


# ==========================================
# VERIFICAR PAREDE
# ==========================================

func verificar_parede(direcao: Vector3) -> bool:

	var space_state = (
		get_world_3d().direct_space_state
	)

	var origem = global_position
	var destino = origem + direcao * distancia_parede

	var query = PhysicsRayQueryParameters3D.create(
		origem,
		destino
	)

	query.exclude = [get_rid()]

	var resultado = space_state.intersect_ray(query)

	return resultado.is_empty()


# ==========================================
# VERIFICAR DIREÇÃO LIVRE
# ==========================================

func pode_andar(direcao: Vector3) -> bool:

	var space_state = (
		get_world_3d().direct_space_state
	)

	var origem = global_position

	var destino = (
		origem +
		direcao.normalized() * distancia_parede
	)

	var query = PhysicsRayQueryParameters3D.create(
		origem,
		destino
	)

	query.exclude = [get_rid()]

	var resultado = space_state.intersect_ray(query)

	return resultado.is_empty()


# ==========================================
# MORTE POR ATROPELAMENTO
# ==========================================

func morrer_atropelado() -> void:

	if esta_morto:
		return

	esta_morto = true

	em_susto = false
	em_sprint = false
	aguardando_aterrissagem = false

	GameManager.adicionar_pontos(
		10,
		global_position
	)

	GameManager.registrar_gnomo()

	# ANIMAÇÃO: PARAR GnomoFugindo
	# $AnimationPlayer.stop()

	# AUDIO: PARAR GnomoSons
	# _timer_som.stop()
	# $GnomoSons.stop()

	# AUDIO: GnomoMorrendo
	# $GnomoMorrendo.play()

	# PARTICULA: GnomoMorte
	# $GnomoMorte.emitting = true

	hide()

	$CollisionShape3D.set_deferred(
		"disabled",
		true
	)

	$Area3D/CollisionShape3D.set_deferred(
		"disabled",
		true
	)

	# Som original
	$AudioStreamPlayer/Morreu.play()

	await get_tree().create_timer(1.0).timeout

	queue_free()
