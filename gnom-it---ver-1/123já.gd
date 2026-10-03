extends Label

@export var fundo: ColorRect
@export var tamanho_final: int = 100

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	for t in ["3", "2", "1"]:
		_mostrar(t)
		await get_tree().create_timer(1.0).timeout

	add_theme_font_size_override("font_size", tamanho_final)
	_mostrar("DESTRUA TUDO!")
	await get_tree().create_timer(1.0).timeout

	if fundo:
		fundo.visible = false
	visible = false
	get_tree().paused = false

func _mostrar(t: String) -> void:
	text = t
	set_anchors_preset(Control.PRESET_TOP_LEFT)   # solta das âncoras
	reset_size()                                  # encolhe a caixa para o tamanho do texto
	var tela := get_viewport_rect().size
	global_position = (tela - size) / 2.0         # centro exato da tela
