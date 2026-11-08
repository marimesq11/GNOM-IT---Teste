extends Label

func _process(_delta: float) -> void:
	text = "Pontos: " + str(GameManager.pontos)
