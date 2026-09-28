extends Node3D

# Uma lista (Array) onde você pode adicionar os 4 tipos de inimigos no Inspetor
@export var tipos_inimigos: Array[PackedScene] = []

@onready var timer: Timer = $SpawnerFrente/Timer

func _ready():
	if tipos_inimigos.is_empty():
		print("Aviso: Nenhum inimigo foi adicionado na lista do Spawner!")
		return

	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	if tipos_inimigos.is_empty():
		return

	# Escolhe aleatoriamente um dos 4 tipos de inimigos da lista
	var inimigo_escolhido_cena = tipos_inimigos.pick_random() as PackedScene
	if not inimigo_escolhido_cena:
		return

	# Instancia o inimigo sorteado
	var inimigo = inimigo_escolhido_cena.instantiate()

	# Define a posição (você pode adicionar um pequeno deslocamento aleatório X/Z se quiser que eles não nasçam exatamente no mesmo pixel)
	var offset_aleatorio = Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
	inimigo.global_position = global_position + offset_aleatorio

	# Adiciona o inimigo na cena principal
	get_tree().current_scene.add_child(inimigo)
