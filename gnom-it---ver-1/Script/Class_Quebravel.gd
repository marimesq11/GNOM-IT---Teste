class_name Quebravel
extends Node

const POPUP_PONTOS = preload("res://Cenas/PopupPontos.tscn")
const POPUP_TEMPO = preload("res://Cenas/PopupTempo.tscn")

# ========================================
# CONFIGURAÇÕES
# ========================================

const TEMPO_BONUS := 3

const PONTOS_ARBUSTO := 10
const PONTOS_CAIXA := 20
const PONTOS_FLOR := 5


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

		# emitir_particula(objeto, cena, "ParticulaArbusto")
		# tocar_som(objeto, cena, "SomArbusto")

	# ========================================
	# CAIXA
	# ========================================

	elif objeto.is_in_group("madeira"):
		pontos = PONTOS_CAIXA

		# emitir_particula(objeto, cena, "ParticulaCaixa")
		# tocar_som(objeto, cena, "SomCaixa")

	# ========================================
	# FLOR
	# ========================================

	elif objeto.is_in_group("flor"):
		pontos = PONTOS_FLOR

		# emitir_particula(objeto, cena, "ParticulaFlor")
		# tocar_som(objeto, cena, "SomFlor")

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
	popup_pontos.modulate = Color.WHITE
	popup_pontos.outline_modulate = Color.BLACK
	popup_pontos.outline_size = 12
	popup_pontos.aparecer("+%d" % pontos)

	# ========================================
	# ADICIONAR TEMPO
	# ========================================

	var fase = objeto.get_tree().get_first_node_in_group("fase")

	if fase:
		fase.adicionar_tempo(TEMPO_BONUS)

	# ========================================
	# POPUP DE TEMPO (2D)
	# ========================================

	var marker = cena.find_child("PopUpTempo", true, false)

	if marker is Marker2D:
		var popup_tempo = POPUP_TEMPO.instantiate()

		# Adiciona na mesma camada do marcador
		marker.add_child(popup_tempo)

		# Centraliza no marcador
		popup_tempo.position = Vector2.ZERO

		# Exibe o tempo
		popup_tempo.aparecer("+%ds" % TEMPO_BONUS)

	# ========================================
	# DESTRUIR OBJETO
	# ========================================

	GameManager.registrar_objeto()
	objeto.queue_free()


# ========================================
# FUNÇÃO PARA EMITIR PARTÍCULAS
# ========================================

# static func emitir_particula(
# 	objeto: Node,
# 	cena: Node,
# 	nome: String
# ) -> void:
#
# 	var particula = objeto.find_child(nome, true, false)
#
# 	if particula == null:
# 		return
#
# 	if not particula is GPUParticles3D:
# 		return
#
# 	var pos = particula.global_transform
#
# 	particula.reparent(cena)
# 	particula.global_transform = pos
#
# 	particula.one_shot = true
# 	particula.restart()
# 	particula.emitting = true
#
# 	particula.get_tree().create_timer(
# 		particula.lifetime + 0.5
# 	).timeout.connect(particula.queue_free)


# ========================================
# FUNÇÃO PARA TOCAR SONS
# ========================================

# static func tocar_som(
# 	objeto: Node,
# 	cena: Node,
# 	nome: String
# ) -> void:
#
# 	var som = objeto.find_child(nome, true, false)
#
# 	if som == null:
# 		return
#
# 	if not som is AudioStreamPlayer3D:
# 		return
#
# 	var pos = som.global_transform
#
# 	som.reparent(cena)
# 	som.global_transform = pos
#
# 	som.play()
# 	som.finished.connect(som.queue_free)
