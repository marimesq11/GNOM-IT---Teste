extends Area3D

@export var Cortador = "res://Cenas/CortadorGrama.tscn"
@export var circulo = "res://Circulo_Pontuação.tscn"

@export_group("Som")
@export var som_coleta: AudioStream

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.adicionar_pontos(25, global_position)
		_tocar_som()
		get_parent_node_3d().queue_free()

func _tocar_som() -> void:
	if som_coleta == null:
		return

	var audio = AudioStreamPlayer3D.new()
	get_tree().current_scene.add_child(audio)
	audio.global_position = global_position
	audio.stream = som_coleta
	audio.finished.connect(audio.queue_free)
	audio.play()
