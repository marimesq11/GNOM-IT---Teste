extends ProgressBar

@export var jogador: CharacterBody3D

@export var cor_dash_pronto := Color(1.0, 0.8, 0.1)
@export var cor_dash_indisponivel := Color(1.0, 1.0, 1.0)

var estilo_preenchimento: StyleBoxFlat


func _ready() -> void:
	# Cria o preenchimento amarelo
	estilo_preenchimento = StyleBoxFlat.new()
	estilo_preenchimento.bg_color = cor_dash_pronto

	add_theme_stylebox_override("fill", estilo_preenchimento)

	# Conecta os sinais
	jogador.gasolina_alterada.connect(_atualizar_valor)
	jogador.dash_disponivel_alterado.connect(_atualizar_cor)

	_iniciar.call_deferred()


func _iniciar() -> void:
	_atualizar_valor(jogador.gasolina, jogador.gasolina_maxima)
	_atualizar_cor(true)


func _atualizar_valor(atual: float, maximo: float) -> void:
	max_value = maximo
	value = atual


func _atualizar_cor(disponivel: bool) -> void:
	if disponivel:
		estilo_preenchimento.bg_color = cor_dash_pronto
	else:
		estilo_preenchimento.bg_color = cor_dash_indisponivel
