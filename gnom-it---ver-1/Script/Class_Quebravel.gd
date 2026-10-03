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

	# Partícula
	var particula = objeto.find_child("Quebrou", true, false)

	if particula:
		var pos = particula.global_transform

		particula.reparent(cena)
		particula.global_transform = pos

		particula.one_shot = true
		particula.restart()
		particula.emitting = true

		particula.get_tree().create_timer(
			particula.lifetime + 0.5
		).timeout.connect(particula.queue_free)

	# Popup +3s
	var popup = POPUP.instantiate()
	cena.add_child(popup)

	popup.global_position = objeto.global_position
	popup.modulate = Color.WHITE
	popup.outline_modulate = Color.BLACK
	popup.outline_size = 12
	popup.aparecer("+%ds" % TEMPO_BONUS)

	# Adiciona 3 segundos
	var fase = objeto.get_tree().get_first_node_in_group("fase")

	if fase:
		fase.adicionar_tempo(TEMPO_BONUS)


	# Quebra o objeto
	objeto.queue_free()
