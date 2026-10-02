extends Area3D
@export var Cortador = ("res://Cenas/CortadorGrama.tscn")
@export var circulo = ("res://Circulo_Pontuação.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: CharacterBody3D) -> void:
	body.is_in_group("player")
	GameManager.adicionar_pontos(25, global_position)


func _on_body_exited(body: CharacterBody3D) -> void:
	get_parent_node_3d().queue_free()
