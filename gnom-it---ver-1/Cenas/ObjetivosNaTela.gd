
extends Label

@export_group("Metas da HUD")
@export var meta_grama: float = 75.0
@export var porcentagem_grama_maxima: float = 60.0

func _process(_delta: float) -> void:
	atualizar_desafios()

func atualizar_desafios() -> void:
	var gnomos: int = GameManager.gnomos_destruidos
	var objetos: int = GameManager.objetos_destruidos

	# Converte 60% de grama real em 100% da escala.
	var grama_normalizada: float = 0.0
	if porcentagem_grama_maxima > 0.0:
		grama_normalizada = clampf(
			GameManager.porcentagem_grama / porcentagem_grama_maxima * 100.0,
			0.0,
			100.0
		)

	# Monta o texto e atualiza durante a partida.
	text = "Desafios:\n\n"
	text += "Gnomos destruídos: %d/%d\n\n" % [gnomos, GameManager.meta_gnomos]
	text += "Decorações quebradas: %d/%d\n\n" % [objetos, GameManager.meta_objetos]
	text += "Grama cortada: %.0f%%/%.0f%%" % [minf(grama_normalizada, meta_grama), meta_grama]
