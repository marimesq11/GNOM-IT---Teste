extends Area3D

@export var Cortador = "res://Cenas/CortadorGrama.tscn"
@export var circulo = "res://Circulo_Pontuação.tscn"


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.adicionar_pontos(25, global_position)
		get_parent_node_3d().queue_free()
