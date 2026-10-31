
extends CharacterBody3D

# MOVIMENTO
@export var velocidade_fuga: float = 2.7
@export var velocidade_sprint: float = 9.0
@export var aceleracao: float = 12.0
@export var velocidade_rotacao: float = 10.0
@export var gravidade: float = 9.8

# DETECÇÃO E FUGA
@export var distancia_deteccao: float = 7.0
@export var distancia_segura: float = 13.0
@export var distancia_parede: float = 2.0
@export var altura_raycast: float = 0.5
@export_flags_3d_physics var mascara_obstaculos: int = 1

# SUSTO E PULO
@export var forca_pulo: float = 5.0
@export var tempo_susto: float = 1.5
@export var duracao_sprint: float = 2.0

# TREMEDEIRA
@export var modelo_gnomo: Node3D
@export var intensidade_tremedeira: float = 0.25
@export var velocidade_tremedeira: float = 22.0

# EXCLAMAÇÃO
@export var cena_popup: PackedScene
@export var altura_popup: float = 2.0
@export var escala_popup: float = 2.0

# SEPARAÇÃO ENTRE GNOMOS
@export var raio_separacao: float = 1.5
@export var forca_separacao: float = 1.5

# ANTI-TRAVAMENTO
@export var tempo_para_detectar_travamento: float = 0.5
@export var duracao_desvio: float = 1.0
@export var distancia_minima_movimento: float = 0.15

# SONS
@export var intervalo_som_min: float = 1.0
@export var intervalo_som_max: float = 3.0
@export var pitch_som_min: float = 0.8
@export var pitch_som_max: float = 1.4

# VARIÁVEIS
var player: Node3D = null
var esta_morto: bool = false
var assustado: bool = false
var em_susto: bool = false
var em_sprint: bool = false
var fugindo: bool = false
var aguardando_aterrissagem: bool = false
var sprint_finalizada: bool = false

var tempo_susto_atual: float = 0.0
var tempo_sprint_atual: float = 0.0
var tempo_tremedeira: float = 0.0
var rotacao_visual_original: Vector3 = Vector3.ZERO

var direcao_fuga: Vector3 = Vector3.ZERO
var direcao_desvio: Vector3 = Vector3.ZERO
var tempo_travado: float = 0.0
var tempo_desvio_atual: float = 0.0
var ultima_posicao: Vector3 = Vector3.ZERO
var _timer_som: Timer

# INICIALIZAÇÃO
func _ready() -> void:
	add_to_group("gnomos_fujoes")
	ultima_posicao = global_position

	if modelo_gnomo != null:
		rotacao_visual_original = modelo_gnomo.rotation

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

# PROCESSAMENTO FÍSICO
func _physics_process(delta: float) -> void:
	if esta_morto or not is_instance_valid(player):
		return

	if em_susto or aguardando_aterrissagem:
		olhar_para_jogador(delta)
	
	var distancia = distancia_horizontal(player.global_position, global_position)

	# DETECTAR JOGADOR
	if distancia <= distancia_deteccao and not assustado:
		iniciar_susto()

	# GRAVIDADE
	if not is_on_floor():
		velocity.y -= gravidade * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# SUSTO
	if em_susto:
		tempo_susto_atual -= delta
		velocity.x = move_toward(velocity.x, 0.0, aceleracao * delta)
		velocity.z = move_toward(velocity.z, 0.0, aceleracao * delta)

		move_and_slide()

		if not is_on_floor():
			atualizar_tremedeira(delta)
		else:
			parar_tremedeira()

		if tempo_susto_atual <= 0.0:
			em_susto = false
			aguardando_aterrissagem = true
			parar_tremedeira()

		ultima_posicao = global_position
		return

	# AGUARDAR ATERRISSAGEM
	if aguardando_aterrissagem:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()

		if is_on_floor():
			aguardando_aterrissagem = false
			parar_tremedeira()
			if not sprint_finalizada:
				iniciar_sprint()

		ultima_posicao = global_position
		return

	# CONTADOR DA SPRINT
	if em_sprint:
		tempo_sprint_atual -= delta
		if tempo_sprint_atual <= 0.0:
			em_sprint = false
			sprint_finalizada = true
			tempo_sprint_atual = 0.0
			print("SPRINT FINALIZADA!")

	# CONTROLE DA FUGA
	if em_sprint:
		fugindo = true
	elif fugindo and distancia >= distancia_segura:
		fugindo = false
		assustado = false
		sprint_finalizada = false
		direcao_fuga = Vector3.ZERO
		tempo_travado = 0.0
		tempo_desvio_atual = 0.0
		print("GNOMO CHEGOU A UMA DISTÂNCIA SEGURA!")

	# MOVIMENTO
	if fugindo:
		atualizar_fuga(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, aceleracao * delta)
		velocity.z = move_toward(velocity.z, 0.0, aceleracao * delta)
		_timer_som.stop()

	move_and_slide()


		# ROTAÇÃO
	if fugindo:
		olhar_para_direcao_fuga(delta)

	# ANTI-TRAVAMENTO
	if fugindo:
		verificar_travamento(delta)

	ultima_posicao = global_position

# TREMEDEIRA PARA FRENTE E PARA TRÁS
func atualizar_tremedeira(delta: float) -> void:
	if modelo_gnomo == null:
		return

	tempo_tremedeira += delta
	var inclinacao = sin(tempo_tremedeira * velocidade_tremedeira) * intensidade_tremedeira
	modelo_gnomo.rotation.z = rotacao_visual_original.z + inclinacao

func parar_tremedeira() -> void:
	if modelo_gnomo == null:
		return

	modelo_gnomo.rotation = rotacao_visual_original
	tempo_tremedeira = 0.0

# DISTÂNCIA HORIZONTAL
func distancia_horizontal(a: Vector3, b: Vector3) -> float:
	var diferenca = a - b
	diferenca.y = 0.0
	return diferenca.length()

# ATUALIZAR FUGA
func atualizar_fuga(delta: float) -> void:
	var direcao_player = global_position - player.global_position
	direcao_player.y = 0.0
	direcao_player = direcao_player.normalized()

	if tempo_desvio_atual > 0.0:
		tempo_desvio_atual -= delta
		if verificar_parede(direcao_desvio):
			direcao_fuga = direcao_desvio
		else:
			tempo_desvio_atual = 0.0
			direcao_fuga = encontrar_melhor_direcao(direcao_player)
	else:
		direcao_fuga = encontrar_melhor_direcao(direcao_player)

	# EVITAR OUTROS GNOMOS
	var separacao = calcular_separacao()
	if separacao.length() > 0.01:
		var direcao_combinada = (direcao_fuga + separacao * forca_separacao).normalized()
		if verificar_parede(direcao_combinada):
			direcao_fuga = direcao_combinada

	# VELOCIDADE
	var velocidade_atual = velocidade_sprint if em_sprint else velocidade_fuga
	var velocidade_desejada = direcao_fuga * velocidade_atual
	velocity.x = move_toward(velocity.x, velocidade_desejada.x, aceleracao * delta)
	velocity.z = move_toward(velocity.z, velocidade_desejada.z, aceleracao * delta)

	# ANIMAÇÃO: GnomoFugindo
	# if $AnimationPlayer.current_animation != "GnomoFugindo":
	#     $AnimationPlayer.play("GnomoFugindo")

	# AUDIO: GnomoSons
	# if _timer_som.is_stopped():
	#     _agendar_som_fuga()

# ENCONTRAR MELHOR DIREÇÃO
func encontrar_melhor_direcao(direcao_desejada: Vector3) -> Vector3:
	if direcao_desejada.length() < 0.01:
		return Vector3.ZERO

	var angulos = [0.0, 25.0, -25.0, 50.0, -50.0, 75.0, -75.0, 100.0, -100.0, 135.0, -135.0, 180.0]
	var melhor_direcao = Vector3.ZERO
	var melhor_pontuacao = -99999.0

	for angulo in angulos:
		var direcao = direcao_desejada.rotated(Vector3.UP, deg_to_rad(angulo)).normalized()
		var distancia_livre = medir_distancia_livre(direcao)
		var alinhamento = direcao.dot(direcao_desejada)
		var pontuacao = distancia_livre * 2.0 + alinhamento * 3.0

		if distancia_livre < 0.8:
			pontuacao -= 15.0

		if pontuacao > melhor_pontuacao:
			melhor_pontuacao = pontuacao
			melhor_direcao = direcao

	return melhor_direcao

# MEDIR DISTÂNCIA LIVRE
func medir_distancia_livre(direcao: Vector3) -> float:
	if direcao.length() < 0.01:
		return 0.0

	var origem = global_position + Vector3.UP * altura_raycast
	var destino = origem + direcao.normalized() * distancia_parede
	var query = PhysicsRayQueryParameters3D.create(origem, destino)
	query.exclude = [get_rid()]
	query.collision_mask = mascara_obstaculos

	var resultado = get_world_3d().direct_space_state.intersect_ray(query)
	if resultado.is_empty():
		return distancia_parede

	return origem.distance_to(resultado["position"])

# VERIFICAR PAREDE
func verificar_parede(direcao: Vector3) -> bool:
	return medir_distancia_livre(direcao) >= distancia_parede - 0.05

# VERIFICAR DIREÇÃO LIVRE
func pode_andar(direcao: Vector3) -> bool:
	return verificar_parede(direcao)

# SEPARAÇÃO ENTRE GNOMOS
func calcular_separacao() -> Vector3:
	var forca = Vector3.ZERO
	var quantidade = 0

	for gnomo in get_tree().get_nodes_in_group("gnomos_fujoes"):
		if gnomo == self or not is_instance_valid(gnomo):
			continue
		if gnomo.esta_morto:
			continue

		var diferenca = global_position - gnomo.global_position
		diferenca.y = 0.0
		var distancia = diferenca.length()

		if distancia > 0.01 and distancia < raio_separacao:
			var intensidade = (raio_separacao - distancia) / raio_separacao
			forca += diferenca.normalized() * intensidade
			quantidade += 1

	if quantidade > 0:
		forca /= quantidade

	return forca.normalized() if forca.length() > 0.01 else Vector3.ZERO

# DETECTAR TRAVAMENTO
func verificar_travamento(delta: float) -> void:
	var movimento = distancia_horizontal(global_position, ultima_posicao)
	var velocidade_atual = velocidade_sprint if em_sprint else velocidade_fuga
	var movimento_esperado = velocidade_atual * delta

	if movimento < movimento_esperado * 0.15 and movimento < distancia_minima_movimento:
		tempo_travado += delta
	else:
		tempo_travado = 0.0

	if tempo_travado >= tempo_para_detectar_travamento:
		escolher_desvio_emergencia()
		tempo_travado = 0.0

# DESVIO DE EMERGÊNCIA
func escolher_desvio_emergencia() -> void:
	var direcao_player = global_position - player.global_position
	direcao_player.y = 0.0
	direcao_player = direcao_player.normalized()

	var melhor_direcao = Vector3.ZERO
	var maior_distancia = -1.0

	for i in range(16):
		var angulo = TAU * float(i) / 16.0
		var direcao = Vector3(cos(angulo), 0.0, sin(angulo))
		var distancia_livre = medir_distancia_livre(direcao)
		var pontuacao = distancia_livre + direcao.dot(direcao_player) * 0.5

		if pontuacao > maior_distancia:
			maior_distancia = pontuacao
			melhor_direcao = direcao

	direcao_desvio = melhor_direcao
	tempo_desvio_atual = duracao_desvio
	print("GNOMO DESVIANDO DE OBSTÁCULO!")

# INICIAR SUSTO
func iniciar_susto() -> void:
	if esta_morto or assustado:
		return

	assustado = true
	em_susto = true
	em_sprint = false
	fugindo = false
	sprint_finalizada = false
	aguardando_aterrissagem = false

	tempo_susto_atual = tempo_susto
	tempo_sprint_atual = 0.0
	tempo_travado = 0.0
	tempo_tremedeira = 0.0

	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = forca_pulo

	_timer_som.stop()
	print("GNOMO ASSUSTADO!")

	# ANIMAÇÃO: GnomoBalançando
	# $AnimationPlayer.play("GnomoBalançando")

	criar_exclamacao()

# INICIAR SPRINT
func iniciar_sprint() -> void:
	if esta_morto or sprint_finalizada or em_sprint:
		return

	em_sprint = true
	fugindo = true
	tempo_sprint_atual = duracao_sprint
	print("GNOMO EM SPRINT!")

	# ANIMAÇÃO: GnomoFugindo
	# $AnimationPlayer.play("GnomoFugindo")

# POPUP DE EXCLAMAÇÃO
func criar_exclamacao() -> void:
	if cena_popup == null:
		print("ERRO: CENA POPUP NÃO CONFIGURADA!")
		return

	var popup = cena_popup.instantiate() as Label3D
	if popup == null:
		print("ERRO: POPUP NÃO É LABEL3D!")
		return

	get_tree().current_scene.add_child(popup)
	popup.global_position = global_position + Vector3(0, altura_popup, 0)
	popup.text = "!"
	popup.modulate = Color.YELLOW
	popup.scale *= escala_popup

	# BALANÇO
	var tween_balanco = create_tween()
	tween_balanco.tween_property(popup, "rotation:z", 0.25, 0.2)
	tween_balanco.tween_property(popup, "rotation:z", -0.25, 0.2)
	tween_balanco.tween_property(popup, "rotation:z", 0.25, 0.2)
	tween_balanco.tween_property(popup, "rotation:z", -0.25, 0.2)
	tween_balanco.tween_property(popup, "rotation:z", 0.0, 0.2)

	# SUBIR LENTAMENTE
	var tween_subida = create_tween()
	tween_subida.tween_property(popup, "position:y", popup.position.y + 0.4, tempo_susto)

	# DESAPARECER GRADUALMENTE
	var tween_fade = create_tween()
	tween_fade.tween_property(popup, "modulate:a", 0.0, tempo_susto)
	tween_fade.tween_callback(popup.queue_free)

# SONS ALEATÓRIOS
func _agendar_som_fuga() -> void:
	if esta_morto:
		return

	var intervalo = randf_range(intervalo_som_min, intervalo_som_max)
	_timer_som.start(maxf(intervalo, 0.01))

func _tocar_som_fuga() -> void:
	if esta_morto or not fugindo:
		return

	# AUDIO: GnomoSons
	# $GnomoSons.pitch_scale = randf_range(pitch_som_min, pitch_som_max)
	# $GnomoSons.play()
	# _agendar_som_fuga()

# MORTE POR ATROPELAMENTO
func morrer_atropelado() -> void:
	if esta_morto:
		return

	esta_morto = true
	em_susto = false
	em_sprint = false
	fugindo = false
	aguardando_aterrissagem = false
	_timer_som.stop()
	parar_tremedeira()

	GameManager.adicionar_pontos(10, global_position)
	GameManager.registrar_gnomo()

	# ANIMAÇÃO: PARAR GnomoFugindo
	# $AnimationPlayer.stop()

	# AUDIO: GnomoMorrendo
	# $GnomoMorrendo.play()

	# PARTICULA: GnomoMorte
	# $GnomoMorte.emitting = true

	hide()
	$CollisionShape3D.set_deferred("disabled", true)
	$Area3D/CollisionShape3D.set_deferred("disabled", true)

	$AudioStreamPlayer/Morreu.play()
	await get_tree().create_timer(1.0).timeout
	queue_free()

func olhar_para_jogador(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var direcao = player.global_position - global_position
	direcao.y = 0.0

	if direcao.length_squared() < 0.0001:
		return

	var angulo_desejado = atan2(direcao.x, direcao.z) - PI / 2.0

	rotation.y = lerp_angle(
		rotation.y,
		angulo_desejado,
		clampf(velocidade_rotacao * delta, 0.0, 1.0)
	)
	
func olhar_para_direcao_fuga(delta: float) -> void:
	if direcao_fuga.length_squared() < 0.0001:
		return

	var angulo_desejado = atan2(direcao_fuga.x, direcao_fuga.z) - PI / 2.0

	rotation.y = lerp_angle(
		rotation.y,
		angulo_desejado,
		clampf(velocidade_rotacao * delta, 0.0, 1.0)
	)
