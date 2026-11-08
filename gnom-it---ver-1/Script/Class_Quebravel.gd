
class_name Quebravel
extends Node

const POPUP_PONTOS = preload("res://Cenas/PopupPontos.tscn")
# const POPUP_TEMPO = preload("res://Cenas/PopupTempo.tscn")

# ========================================
# CONFIGURAÇÕES
# ========================================

# const TEMPO_BONUS := 3

const PONTOS_ARBUSTO := 10
const PONTOS_CAIXA := 10
const PONTOS_FLOR := 20

# ========================================
# QUEBRAR OBJETO
# ========================================

static func quebrar(objeto: Node) -> void:
	if objeto == null:
		return

	if not objeto.is_in_group("Quebravel"):
		return

	var cena = objeto.get_tree().current_scene
	if cena == null:
		return

	var pontos := 0

	# ========================================
	# ARBUSTO
	# ========================================

	if objeto.is_in_group("planta"):
		pontos = PONTOS_ARBUSTO
		emitir_particula(objeto, cena, "folhas moita")
		tocar_som(objeto, cena, "ColidirArbusto", 0.8, 1.0)

	# ========================================
	# CAIXA / MADEIRA
	# ========================================

	elif objeto.is_in_group("madeira"):
		pontos = PONTOS_CAIXA
		emitir_particula(objeto, cena, "tábuas quebrando")
		tocar_som(objeto, cena, "CaixaQuebrando")

	# ========================================
	# FLOR
	# ========================================

	elif objeto.is_in_group("flor"):
		pontos = PONTOS_FLOR
		emitir_particula(objeto, cena, "flores quebrando")
		tocar_som(objeto, cena, "ColidirArbusto", 1.0, 1.2)

	else:
		return

	# ========================================
	# ADICIONAR PONTOS
	# ========================================

	GameManager.pontos += pontos

	# ========================================
	# POPUP DE PONTOS (3D)
	# ========================================

	var popup_pontos = POPUP_PONTOS.instantiate()
	cena.add_child(popup_pontos)

	popup_pontos.global_position = objeto.global_position
	popup_pontos.modulate = Color.YELLOW
	popup_pontos.outline_modulate = Color.BLACK
	popup_pontos.outline_size = 12
	popup_pontos.aparecer("+%d" % pontos)

	# ========================================
	# ADICIONAR TEMPO (DESATIVADO)
	# ========================================

	# var fase = objeto.get_tree().get_first_node_in_group("fase")
	#
	# if fase:
	# 	fase.adicionar_tempo(TEMPO_BONUS)

	# ========================================
	# POPUP DE TEMPO (2D) (DESATIVADO)
	# ========================================

	# var marker = cena.find_child("PopUpTempo", true, false)
	#
	# if marker is Marker2D:
	# 	var popup_tempo = POPUP_TEMPO.instantiate()
	# 	marker.add_child(popup_tempo)
	# 	popup_tempo.position = Vector2.ZERO
	# 	popup_tempo.aparecer("+%ds" % TEMPO_BONUS)

	# ========================================
	# DESTRUIR OBJETO
	# ========================================

	GameManager.registrar_objeto()
	objeto.queue_free()

# ========================================
# FUNÇÃO PARA EMITIR PARTÍCULAS
# ========================================

static func emitir_particula(objeto: Node, cena: Node, nome: String) -> void:
	var particula = objeto.find_child(nome, true, false)

	if particula == null:
		push_warning("QUEBRAVEL: Não encontrou a partícula " + nome)
		return

	if not particula is GPUParticles3D and not particula is CPUParticles3D:
		push_warning("QUEBRAVEL: O nó " + nome + " não é uma partícula 3D!")
		return

	# Guarda a posição antes de destruir o objeto
	var posicao_original = particula.global_transform

	# Retira a partícula do objeto para não ser destruída
	particula.reparent(cena)
	particula.global_transform = posicao_original

	# Emite uma única vez
	particula.one_shot = true
	particula.emitting = false
	particula.restart()
	particula.emitting = true

	# Aguarda a emissão terminar antes de remover
	var tempo_total: float = particula.lifetime * (2.0 - particula.explosiveness) / maxf(particula.speed_scale, 0.01) + 0.5

	particula.get_tree().create_timer(tempo_total).timeout.connect(
		func():
			if is_instance_valid(particula):
				particula.queue_free()
	)

# ========================================
# FUNÇÃO PARA TOCAR SONS
# ========================================

static func tocar_som(objeto: Node, cena: Node, nome: String, pitch_min: float = 1.0, pitch_max: float = 1.0) -> void:
	var som_original = objeto.find_child(nome, true, false)

	# PARA A FLOR, PROCURA O SOM NO OBJETO OU EM SUA CENA
	if som_original == null and objeto.is_in_group("flor"):
		som_original = cena.find_child(nome, true, false)

	if som_original == null:
		push_warning("QUEBRAVEL: Não encontrou o som " + nome)
		return

	if not som_original is AudioStreamPlayer3D and not som_original is AudioStreamPlayer:
		push_warning("QUEBRAVEL: O nó encontrado não é um AudioStreamPlayer!")
		return

	if som_original.stream == null:
		push_warning("QUEBRAVEL: O som está sem Stream configurado!")
		return

	var pitch_sorteado := randf_range(pitch_min, pitch_max)
	var pitch_final: float = som_original.pitch_scale * pitch_sorteado

	# SOM 3D
	if som_original is AudioStreamPlayer3D:
		var novo_som = AudioStreamPlayer3D.new()
		novo_som.stream = som_original.stream
		novo_som.volume_db = som_original.volume_db
		novo_som.pitch_scale = pitch_final
		novo_som.bus = som_original.bus
		novo_som.unit_size = som_original.unit_size
		novo_som.max_distance = som_original.max_distance

		cena.add_child(novo_som)
		novo_som.global_position = objeto.global_position
		novo_som.finished.connect(novo_som.queue_free)
		novo_som.play()

	# SOM 2D
	elif som_original is AudioStreamPlayer:
		var novo_som = AudioStreamPlayer.new()
		novo_som.stream = som_original.stream
		novo_som.volume_db = som_original.volume_db
		novo_som.pitch_scale = pitch_final
		novo_som.bus = som_original.bus

		cena.add_child(novo_som)
		novo_som.finished.connect(novo_som.queue_free)
		novo_som.play()
