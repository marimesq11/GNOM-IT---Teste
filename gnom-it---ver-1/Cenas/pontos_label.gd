
extends Label


func _ready() -> void:
	var pontos = GameManager.pontos
	var desempenho = GameManager.calcular_desempenho()
	var estrelas = GameManager.calcular_estrelas()

	# Desenha as estrelas obtidas e as que faltaram.
	var estrelas_texto = ""

	for i in range(3):
		if i < estrelas:
			estrelas_texto += "★"
		else:
			estrelas_texto += "☆"

	# Monta o texto da tela de vitória.
	text = (
		estrelas_texto +
		"\nPontos: " + str(pontos) +
		"\nDesempenho: " + str(roundi(desempenho)) + "%"
	)
