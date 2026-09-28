extends ProgressBar

@export var cortador: CharacterBody3D


func _ready():
	min_value = 0.0

	if cortador == null:
		return

	max_value = cortador.vida_maxima
	value = cortador.vida
	cortador.vida_alterada.connect(_quando_vida_mudar)


func _quando_vida_mudar(vida_atual, vida_max):
	max_value = vida_max
	value = vida_atual
