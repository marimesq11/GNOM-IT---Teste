class_name Abastecimento
extends Area3D

@export var recarga_por_segundo: float = 20.0


func _physics_process(delta: float) -> void:
	for corpo in get_overlapping_bodies():
		if corpo.has_method("reabastecer"):
			corpo.reabastecer(recarga_por_segundo * delta)
