class_name Quebravel
extends Node

const POPUP = preload("res://Cenas/PopupPontos.tscn")  # ajuste o caminho
const TEMPO_BONUS := 3

static func quebrar(objeto):
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
		particula.get_tree().create_timer(particula.lifetime + 0.5).timeout.connect(particula.queue_free)

	# Popup com o tempo adicionado
	var popup = POPUP.instantiate()
	cena.add_child(popup)  # primeiro adiciona na cena...
	popup.global_position = objeto.global_position  # ...depois posiciona
	# Popup com o tempo adicionado
	cena.add_child(popup)
	popup.global_position = objeto.global_position
	popup.text = "+%ds" % TEMPO_BONUS
	popup.modulate = Color.WHITE
	popup.outline_modulate = Color.BLACK
	popup.outline_size = 12
	popup.aparecer()

	# Tempo da fase
	var fase = objeto.get_tree().get_first_node_in_group("fase")
	if fase:
		fase.adicionar_tempo(TEMPO_BONUS)

	objeto.queue_free()
