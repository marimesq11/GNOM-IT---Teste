extends Node

var pontos = 0
var popup_pontos = preload("res://Cenas/PopupPontos.tscn")

func adicionar_pontos(valor: int, posicao_3d: Vector3):
	pontos += valor
	
	var popup = popup_pontos.instantiate()
	popup.global_position = posicao_3d
	get_tree().current_scene.add_child(popup)
	popup.aparecer()
