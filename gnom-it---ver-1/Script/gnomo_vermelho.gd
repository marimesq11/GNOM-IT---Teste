extends CharacterBody3D

@export_group("Partícula de Morte")
@export var controlador_cor_morte: CorMorteGnomo
# ==========================================
# GRAVIDADE
# ==========================================
var gravidade: float = 9.8
# ==========================================
# DANO
# ==========================================
@export var dano: float = 1
var sendo_atropelado: bool = false
# ==========================================
# VELOCIDADE
# ==========================================
@export var velocidade: float = 3.5
@export var velocidade_ataque: float = 3.0
@export var velocidade_inicial: float = 0.5
@export var aceleracao: float = 1.5

var velocidade_atual: float = 0.0
var velocidade_rotacao: float = 2.0
# ==========================================
# CORTADOR
# ==========================================

@export var Cortador: CharacterBody3D

# ==========================================
# DISTÂNCIA
# ==========================================

var distancia_cercar: float = 0.6
var forca_recuo: float = 0.6


# ==========================================
# TEMPO
# ==========================================

var tempo_parado: float = 0.5


# ==========================================
# CONFIGURAÇÕES DOS SONS DE PERSEGUIÇÃO
# ==========================================

# Intervalo individual de cada gnomo
@export var intervalo_som_min: float = 12.0
@export var intervalo_som_max: float = 25.0

# Intervalo compartilhado por TODOS os gnomos
@export var intervalo_global_perseguicao: float = 5.0

# Variação da voz
@export var pitch_som_min: float = 0.8
@export var pitch_som_max: float = 1.4

# Volume
# VOLUME DOS SONS
@export_range(-40.0, 10.0, 1.0) var volume_perseguicao: float = -8.0
@export_range(-40.0, 10.0, 1.0) var volume_ataque: float = -6.0


# ==========================================
# CONFIGURAÇÕES DOS SONS DE ATAQUE
# ==========================================

# Tenta tocar a cada 3 ataques acertados
@export var ataques_por_som: int = 3

# Chance de tocar quando atingir a contagem
@export_range(0.0, 100.0, 1.0) var chance_som_ataque: float = 45.0

# Intervalo compartilhado entre todos os gnomos
@export var intervalo_global_ataque: float = 8.0

# Volume
@export_range(-40.0, 10.0, 1.0) var volume_ataque_db: float = -6.0


# ==========================================
# CONTROLE GLOBAL DOS SONS
# ==========================================

# Estas variáveis são compartilhadas entre todas
# as instâncias deste script.

static var proximo_som_perseguicao: float = 0.0
static var proximo_som_ataque: float = 0.0

# Impede repetir o mesmo som de perseguição
# consecutivamente, mesmo entre gnomos diferentes.
static var ultimo_som_global: int = -1


# ==========================================
# SONS DE MORTE
# ==========================================

@export var som_morte_gnomo_1: AudioStreamPlayer
@export var som_morte_gnomo_2: AudioStreamPlayer
@export var som_morte_gnomo_3: AudioStreamPlayer
@export var som_morte_gnomo_4: AudioStreamPlayer

@onready var som_morreu: AudioStreamPlayer = $AudioStreamPlayer/Morreu


# ==========================================
# SONS DE PERSEGUIÇÃO E ATAQUE
# ==========================================

@onready var som_barulinho_1: AudioStreamPlayer = $AudioStreamPlayer/Barulinhos
@onready var som_barulinho_2: AudioStreamPlayer = $AudioStreamPlayer/Barulinhos2
@onready var som_barulinho_3: AudioStreamPlayer = $AudioStreamPlayer/Barulinhos3

@onready var som_ataque: AudioStreamPlayer = $AudioStreamPlayer/Ataque


# ==========================================
# ESTADOS
# ==========================================

var atacando: bool = false
var parado: bool = false


# ==========================================
# CONTADOR DE ATAQUES
# ==========================================

var contador_ataques: int = 0


# ==========================================
# POSIÇÃO DO INIMIGO NO CÍRCULO
# ==========================================

var indice_inimigo: int = 0
var quantidade_inimigos: int = 1


# ==========================================
# TIMER DOS SONS
# ==========================================

var _timer_som: Timer


# ==========================================
# READY
# ==========================================

func _ready() -> void:
	velocidade_atual = velocidade_inicial

	atualizar_grupo()

	# Configura os volumes
	som_barulinho_1.volume_db = volume_perseguicao
	som_barulinho_2.volume_db = volume_perseguicao
	som_barulinho_3.volume_db = volume_perseguicao

	som_ataque.volume_db = volume_ataque_db

	# Cria o timer individual
	_timer_som = Timer.new()
	_timer_som.one_shot = true
	_timer_som.timeout.connect(_tocar_som_perseguicao)
	add_child(_timer_som)

	# Agenda o primeiro som
	_agendar_som_perseguicao()


# ==========================================
# TEMPO GLOBAL
# ==========================================

func _tempo_atual() -> float:
	return Time.get_ticks_msec() / 1000.0


# ==========================================
# AGENDAR SOM DE PERSEGUIÇÃO
# ==========================================

func _agendar_som_perseguicao() -> void:
	if sendo_atropelado or parado or atacando:
		return

	var minimo = maxf(intervalo_som_min, 0.1)
	var maximo = maxf(intervalo_som_max, minimo)

	var intervalo = randf_range(minimo, maximo)

	_timer_som.start(intervalo)


# ==========================================
# ESCOLHER SOM DE PERSEGUIÇÃO
# ==========================================

func _tocar_som_perseguicao() -> void:
	if sendo_atropelado or parado or atacando:
		return

	var agora = _tempo_atual()

	# Verifica se outro gnomo fez barulho recentemente
	if agora < proximo_som_perseguicao:
		_agendar_som_perseguicao()
		return

	var sons: Array[AudioStreamPlayer] = [
		som_barulinho_1,
		som_barulinho_2,
		som_barulinho_3
	]

	var indices_disponiveis: Array[int] = []

	# Procura sons válidos e evita repetir
	# o último som tocado globalmente.
	for i in range(sons.size()):
		if sons[i] == null:
			continue

		if sons[i].stream == null:
			continue

		if i == ultimo_som_global:
			continue

		indices_disponiveis.append(i)

	# Se não houver alternativa, permite repetir
	if indices_disponiveis.is_empty():
		for i in range(sons.size()):
			if sons[i] != null and sons[i].stream != null:
				indices_disponiveis.append(i)

	if indices_disponiveis.is_empty():
		_agendar_som_perseguicao()
		return

	# Sorteia um dos três sons
	var indice_sorteado: int = indices_disponiveis.pick_random()

	var som_sorteado: AudioStreamPlayer = sons[indice_sorteado]

	# Varia o pitch
	var pitch_minimo = maxf(pitch_som_min, 0.01)
	var pitch_maximo = maxf(pitch_som_max, pitch_minimo)

	som_sorteado.pitch_scale = randf_range(
		pitch_minimo,
		pitch_maximo
	)

	som_sorteado.volume_db = volume_perseguicao

	# Reproduz
	som_sorteado.play()

	# Atualiza o último som utilizado
	ultimo_som_global = indice_sorteado

	# Bloqueia temporariamente os outros gnomos
	proximo_som_perseguicao = agora + maxf(
		intervalo_global_perseguicao,
		0.0
	)

	# Agenda o próximo som deste gnomo
	_agendar_som_perseguicao()


# ==========================================
# PARAR SONS DE PERSEGUIÇÃO
# ==========================================

func _parar_sons_perseguicao() -> void:
	if is_instance_valid(_timer_som):
		_timer_som.stop()

	if som_barulinho_1.playing:
		som_barulinho_1.stop()

	if som_barulinho_2.playing:
		som_barulinho_2.stop()

	if som_barulinho_3.playing:
		som_barulinho_3.stop()


# ==========================================
# SOM DE ATAQUE
# ==========================================

func _tentar_tocar_som_ataque() -> void:
	if sendo_atropelado:
		return

	if som_ataque == null or som_ataque.stream == null:
		return

	# Tenta tocar apenas a cada X ataques
	var quantidade = maxi(ataques_por_som, 1)

	if contador_ataques % quantidade != 0:
		return

	var agora = _tempo_atual()

	# Evita vários gnomos gritando juntos
	if agora < proximo_som_ataque:
		return

	# Chance aleatória de tocar
	if randf() * 100.0 > chance_som_ataque:
		return

	# Toca o som
	som_ataque.volume_db = volume_ataque_db
	som_ataque.play()

	# Bloqueia o som de ataque dos outros gnomos
	proximo_som_ataque = agora + maxf(
		intervalo_global_ataque,
		0.0
	)


# ==========================================
# ATUALIZAR GRUPO
# ==========================================

func atualizar_grupo() -> void:
	var inimigos = get_tree().get_nodes_in_group("inimigos")

	indice_inimigo = inimigos.find(self)
	quantidade_inimigos = max(inimigos.size(), 1)


# ==========================================
# OLHAR PARA JOGADOR
# ==========================================

func olhar_para_jogador(delta: float) -> void:
	if not is_instance_valid(Cortador):
		return

	var direcao = Cortador.global_position - global_position
	direcao.y = 0.0

	if direcao.length_squared() < 0.0001:
		return

	var angulo_desejado = atan2(direcao.x, direcao.z) - PI / 2.0

	rotation.y = lerp_angle(
		rotation.y,
		angulo_desejado,
		clampf(velocidade_rotacao * delta, 0.0, 1.0)
	)


# ==========================================
# PHYSICS PROCESS
# ==========================================

func _physics_process(delta: float) -> void:
	if not is_instance_valid(Cortador):
		return

	# GRAVIDADE
	if not is_on_floor():
		velocity.y -= gravidade * delta
	else:
		velocity.y = 0.0

	# ROTAÇÃO
	olhar_para_jogador(delta)

	# PARADO OU MORTO
	if parado or sendo_atropelado:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# ACELERAÇÃO
	var velocidade_maxima = velocidade_ataque if atacando else velocidade

	velocidade_atual = move_toward(
		velocidade_atual,
		velocidade_maxima,
		aceleracao * delta
	)

	# DISTÂNCIA DO JOGADOR
	var diferenca = Cortador.global_position - global_position
	diferenca.y = 0.0

	var distancia_quadrada = diferenca.length_squared()

	# INICIAR ATAQUE
	if distancia_quadrada <= distancia_cercar * distancia_cercar:
		if not atacando:
			atacando = true

			# ANIMAÇÃO
			# $AnimationPlayer.play("GnomoAtacando")

			_parar_sons_perseguicao()

	# DESTINO
	var destino: Vector3

	if atacando:
		destino = Cortador.global_position
	else:
		var angulo = (TAU / quantidade_inimigos) * indice_inimigo

		var offset = Vector3(
			cos(angulo),
			0.0,
			sin(angulo)
		) * distancia_cercar

		destino = Cortador.global_position + offset

	# MOVIMENTO
	var direcao = destino - global_position
	direcao.y = 0.0

	if direcao.length_squared() > 0.0001:
		direcao = direcao.normalized()

		velocity.x = direcao.x * velocidade_atual
		velocity.z = direcao.z * velocidade_atual
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	# VERIFICAR ATAQUE
	if atacando and not parado:
		var distancia = global_position.distance_to(
			Cortador.global_position
		)

		if distancia <= distancia_cercar:
			ataque_acertou()


# ==========================================
# ATAQUE ACERTOU
# ==========================================

func ataque_acertou() -> void:
	if sendo_atropelado or parado:
		return

	if not is_instance_valid(Cortador):
		return

	atacando = false
	parado = true

	_parar_sons_perseguicao()

	# CONTADOR DE ATAQUES
	contador_ataques += 1
	_tentar_tocar_som_ataque()

	# ========================================
	# CAUSAR DANO AO JOGADOR
	# ========================================

	if Cortador.has_method("receber_dano"):
		Cortador.receber_dano(dano)
		print("GNOMO CAUSOU ", dano, " DE DANO!")

	elif Cortador.has_method("tomar_dano"):
		Cortador.tomar_dano(dano)
		print("GNOMO CAUSOU ", dano, " DE DANO!")

	else:
		push_warning("ERRO: O Cortador não possui uma função de receber dano!")

	# ========================================
	# RECUO
	# ========================================

	var direcao_recuo = global_position - Cortador.global_position
	direcao_recuo.y = 0.0

	if direcao_recuo.length_squared() > 0.0001:
		direcao_recuo = direcao_recuo.normalized()
		global_position += direcao_recuo * forca_recuo

	velocity = Vector3.ZERO
	velocidade_atual = velocidade_inicial

	# ESPERA
	await get_tree().create_timer(tempo_parado).timeout

	if is_inside_tree() and not sendo_atropelado:
		parado = false
		_agendar_som_perseguicao()


# ==========================================
# MORRER ATROPELADO
# ==========================================

func morrer_atropelado() -> void:
	if sendo_atropelado:
		return

	print("GNOMO MORREU POR ATROPELAMENTO!")
	print("POSIÇÃO DO GNOMO: ", global_position)

	sendo_atropelado = true
	atacando = false
	parado = true

	velocity = Vector3.ZERO
	if is_instance_valid(controlador_cor_morte):
		controlador_cor_morte.mudar_cor(self)

	# PONTUAÇÃO
	GameManager.adicionar_pontos(50, global_position)
	GameManager.registrar_gnomo()

	# PARA SONS DE PERSEGUIÇÃO
	_parar_sons_perseguicao()

	# PARA SOM DE ATAQUE
	if som_ataque.playing:
		som_ataque.stop()

	# ANIMAÇÃO
	# $AnimationPlayer.stop()

	# PARTÍCULAS
	# $ParticulaGnomoMorte.emitting = true

	# SONS DE MORTE ALEATÓRIOS
	var sons_morte: Array[AudioStreamPlayer] = [
		som_morte_gnomo_1,
		som_morte_gnomo_2,
		som_morte_gnomo_3,
		som_morte_gnomo_4
	]

	sons_morte = sons_morte.filter(
		func(som): return som != null and som.stream != null
	)

	if not sons_morte.is_empty():
		var som_sorteado: AudioStreamPlayer = sons_morte.pick_random()

		som_morreu.stream = som_sorteado.stream
		som_morreu.play()
	else:
		push_warning("Nenhum som de morte configurado no gnomo!")

	# DESATIVA MOVIMENTO
	set_physics_process(false)
	set_process(false)

	hide()

	collision_layer = 0
	collision_mask = 0

	# ESPERA O SOM TERMINAR
	if som_morreu.playing:
		await som_morreu.finished

	queue_free()
