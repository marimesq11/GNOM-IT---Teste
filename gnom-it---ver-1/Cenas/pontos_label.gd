
extends RichTextLabel

@export_group("Estrelas")
@export var tamanho_estrelas: int = 55
@export var cor_estrelas: Color = Color.YELLOW
@export var cor_estrelas_vazias: Color = Color.GRAY
@export_range(0, 30, 1) var espaco_entre_estrelas: int = 5

@export_group("Nota")
@export var tamanho_nota: int = 25
@export var cor_nota: Color = Color.WHITE

@export_group("Pontos")
@export var tamanho_pontos: int = 25
@export var cor_pontos: Color = Color.WHITE

@export_group("Espaçamento")
@export var espaco_entre_linhas: int = 20
@export var espaco_estrelas_nota: int = 15

func _ready() -> void:
	bbcode_enabled = true
	add_theme_constant_override("line_separation", espaco_entre_linhas)

	var pontos = GameManager.pontos
	var desempenho = GameManager.calcular_desempenho()
	var estrelas = GameManager.calcular_estrelas()

	var estrelas_texto = ""
	var separacao_estrelas = "[font_size=%d]%s[/font_size]" % [tamanho_estrelas, " ".repeat(espaco_entre_estrelas)]

	for i in range(3):
		if i > 0:
			estrelas_texto += separacao_estrelas

		if i < estrelas:
			estrelas_texto += "[color=#%s]★[/color]" % cor_estrelas.to_html()
		else:
			estrelas_texto += "[color=#%s]☆[/color]" % cor_estrelas_vazias.to_html()

	var separacao_nota = " ".repeat(maxi(espaco_estrelas_nota / 5, 0))

	text = (
		"[center]" +
		"[font_size=%d]" % tamanho_estrelas +
		estrelas_texto +
		"[/font_size]" +
		separacao_nota +
		"[font_size=%d][color=#%s]" % [tamanho_nota, cor_nota.to_html()] +
		"Nota: %d%%" % roundi(desempenho) +
		"[/color][/font_size]" +
		"\n" +
		"[font_size=%d][color=#%s]" % [tamanho_pontos, cor_pontos.to_html()] +
		"Pontos: %d" % pontos +
		"[/color][/font_size]" +
		"[/center]"
	)
