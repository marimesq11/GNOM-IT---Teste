extends ProgressBar

@export var jogador: CharacterBody3D
@export var cor_dash_pronto := Color(1.0, 0.8, 0.1)
@export var cor_dash_indisponivel := Color(1.0, 1.0, 1.0)


func _ready() -> void:
	jogador.gasolina_alterada.connect(_atualizar_valor)
	jogador.dash_disponivel_alterado.connect(_atualizar_cor)
	_iniciar.call_deferred()


func _iniciar() -> void:
	_atualizar_valor(jogador.gasolina, jogador.gasolina_maxima)
	_atualizar_cor(false)


func _atualizar_valor(atual: float, maximo: float) -> void:
	max_value = maximo
	value = atual

	print("========== BARRA ==========")
	print("JOGADOR: ", jogador.get_path())
	print("GASOLINA RECEBIDA: ", atual)
	print("GASOLINA REAL DO JOGADOR: ", jogador.gasolina)
	print("VALOR DA BARRA: ", value)
	print("===========================")


func _atualizar_cor(disponivel: bool) -> void:
	modulate = cor_dash_pronto if disponivel else cor_dash_indisponivel
