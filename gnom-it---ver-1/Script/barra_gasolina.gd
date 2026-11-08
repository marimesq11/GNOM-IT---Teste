extends ProgressBar

@export var jogador: CharacterBody3D

@export var cor_barra := Color(1.0, 0.8, 0.1)

var estilo_preenchimento: StyleBoxFlat


func _ready() -> void:
	# Cria o preenchimento amarelo
	estilo_preenchimento = StyleBoxFlat.new()
	estilo_preenchimento.bg_color = cor_barra

	add_theme_stylebox_override("fill", estilo_preenchimento)

	# Conecta o sinal da gasolina
	jogador.gasolina_alterada.connect(_atualizar_valor)

	_iniciar.call_deferred()


func _iniciar() -> void:
	_atualizar_valor(jogador.gasolina, jogador.gasolina_maxima)


func _atualizar_valor(atual: float, maximo: float) -> void:
	max_value = maximo
	value = atual
