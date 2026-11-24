
extends Label

@export var fundo: ColorRect
@export var tamanho_final: int = 100

# ELEMENTOS DA HUD QUE DEVEM SUMIR
@export var elementos_hud: Array[CanvasItem] = []

# SOM DA CONTAGEM
@export var MotorEgatando: AudioStreamPlayer

# CONTROLE DA PAUSA
var contando: bool = true


func _ready() -> void:
	# A contagem continua funcionando durante a pausa
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Forca os objetos da fase a respeitarem a pausa
	_forcar_modo_pausavel(get_tree().current_scene)

	# A contagem e o som precisam continuar funcionando
	process_mode = Node.PROCESS_MODE_ALWAYS

	if MotorEgatando:
		MotorEgatando.process_mode = Node.PROCESS_MODE_ALWAYS

	# Esconde a HUD
	for elemento in elementos_hud:
		if is_instance_valid(elemento):
			elemento.visible = false

	# Pausa tudo
	get_tree().paused = true

	# Contagem regressiva
	for t in ["3", "2", "1"]:
		_mostrar(t)

		if t == "1" and MotorEgatando:
			MotorEgatando.play()

		await get_tree().create_timer(1.0).timeout

	# Mensagem final
	add_theme_font_size_override("font_size", tamanho_final)
	_mostrar("DESTRUA TUDO!")

	await get_tree().create_timer(1.0).timeout

	# Finaliza a contagem
	contando = false

	if fundo:
		fundo.visible = false

	visible = false

	# Mostra a HUD
	for elemento in elementos_hud:
		if is_instance_valid(elemento):
			elemento.visible = true

	# Libera o jogo
	get_tree().paused = false


func _process(_delta: float) -> void:
	# Garante que o jogo continue pausado durante a contagem
	if contando:
		get_tree().paused = true


func _forcar_modo_pausavel(no: Node) -> void:
	if no == self:
		return

	# Forca todos os nos da fase a respeitarem a pausa
	no.process_mode = Node.PROCESS_MODE_PAUSABLE

	for filho in no.get_children():
		_forcar_modo_pausavel(filho)


func _mostrar(t: String) -> void:
	text = t
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	reset_size()

	var tela := get_viewport_rect().size
	global_position = (tela - size) / 2.0
