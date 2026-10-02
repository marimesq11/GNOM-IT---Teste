extends Node

var pontos = 0
var popup_pontos = preload("res://Cenas/PopupPontos.tscn")

func adicionar_pontos(valor: int, posicao_3d: Vector3):
	pontos += valor
	print("pontos agora: ", pontos)

	var popup = popup_pontos.instantiate()
	get_tree().current_scene.add_child(popup)  # primeiro entra na cena...
	popup.global_position = posicao_3d         # ...depois posiciona
	popup.aparecer()
