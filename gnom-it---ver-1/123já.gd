extends Label

@export var fundo: ColorRect
@export var tamanho_final: int = 100

# ELEMENTOS DA HUD QUE DEVEM SUMIR
@export var elementos_hud: Array[CanvasItem] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# ESCONDE OS ELEMENTOS DA HUD
	for elemento in elementos_hud:
		if is_instance_valid(elemento):
			elemento.visible = false

	# PAUSA O JOGO
	get_tree().paused = true

	# CONTAGEM
	for t in ["3", "2", "1"]:
		_mostrar(t)
		await get_tree().create_timer(1.0).timeout

	# MENSAGEM FINAL
	add_theme_font_size_override("font_size", tamanho_final)
	_mostrar("DESTRUA TUDO!")
	await get_tree().create_timer(1.0).timeout

	# ESCONDE O FUNDO E A CONTAGEM
	if fundo:
		fundo.visible = false

	visible = false

	# MOSTRA NOVAMENTE OS ELEMENTOS DA HUD
	for elemento in elementos_hud:
		if is_instance_valid(elemento):
			elemento.visible = true

	# DESPAUSA O JOGO
	get_tree().paused = false


func _mostrar(t: String) -> void:
	text = t
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	reset_size()

	var tela := get_viewport_rect().size
	global_position = (tela - size) / 2.0
