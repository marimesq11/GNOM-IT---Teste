class_name Quebravel
extends Node

const POPUP = preload("res://Cenas/PopupPontos.tscn")

const TEMPO_BONUS := 3
const PONTOS_BONUS := 50


static func quebrar(objeto: Node) -> void:
	if objeto == null:
		return

	if not objeto.is_in_group("Quebravel"):
		return

	var cena = objeto.get_tree().current_scene

	# ========================================
	# PARTÍCULAS E SONS POR TIPO DE OBJETO
	# ========================================

	# MADEIRA
	if objeto.is_in_group("madeira"):

		emitir_particula(objeto, cena, "ParticulaMorteMadeira")

		# TOCAR SOM: MadeiraQuebrando
		# var som = objeto.find_child("MadeiraQuebrando", true, false)
		# if som:
		#     tocar_som(som, cena)


	# PLANTA
	if objeto.is_in_group("planta"):

		emitir_particula(objeto, cena, "ParticulaMortePlanta")

		# TOCAR SOM: PlantaAtropelada
		# var som = objeto.find_child("PlantaAtropelada", true, false)
		# if som:
		#     tocar_som(som, cena)


	# MADEIRA GRANDE
	if objeto.is_in_group("grande") and objeto.is_in_group("madeira"):

		emitir_particula(objeto, cena, "ParticulaMadeiraPequena")

		# TOCAR SOM: ObjetoGrandeMadeira
		# var som = objeto.find_child("ObjetoGrandeMadeira", true, false)
		# if som:
		#     tocar_som(som, cena)


	# ========================================
	# PARTÍCULA ORIGINAL
	# ========================================

	emitir_particula(objeto, cena, "Quebrou")


	# ========================================
	# POPUP +3s
	# ========================================

	var popup = POPUP.instantiate()
	cena.add_child(popup)

	popup.global_position = objeto.global_position
	popup.modulate = Color.WHITE
	popup.outline_modulate = Color.BLACK
	popup.outline_size = 12
	popup.aparecer("+%ds" % TEMPO_BONUS)


	# ========================================
	# ADICIONAR TEMPO
	# ========================================

	var fase = objeto.get_tree().get_first_node_in_group("fase")

	if fase:
		fase.adicionar_tempo(TEMPO_BONUS)


	# ========================================
	# DESTRUIR OBJETO
	# ========================================
	GameManager.registrar_objeto()
	objeto.queue_free()


# ========================================
# FUNÇÃO PARA EMITIR PARTÍCULAS
# ========================================

static func emitir_particula(
	objeto: Node,
	cena: Node,
	nome: String
) -> void:

	var particula = objeto.find_child(nome, true, false)

	if particula == null:
		return

	if not particula is GPUParticles3D:
		return

	var pos = particula.global_transform

	particula.reparent(cena)
	particula.global_transform = pos

	particula.one_shot = true
	particula.restart()
	particula.emitting = true

	particula.get_tree().create_timer(
		particula.lifetime + 0.5
	).timeout.connect(particula.queue_free)


# ========================================
# FUNÇÃO PARA TOCAR SONS
# ========================================

# static func tocar_som(
#     som: AudioStreamPlayer3D,
#     cena: Node
# ) -> void:
#
#     var pos = som.global_transform
#
#     som.reparent(cena)
#     som.global_transform = pos
#
#     som.play()
#
#     som.finished.connect(som.queue_free)
