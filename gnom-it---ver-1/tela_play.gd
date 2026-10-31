extends Node2D

# ==========================================
# BOTÕES
# ==========================================

@export var botao_play: TextureButton
@export var botao_tutorial: TextureButton
@export var botao_x: Button
@export var botao_skip: Button

@export var outros_botoes: Array[CanvasItem]


# ==========================================
# TUTORIAL
# ==========================================

@export var sprite_tutorial: Sprite2D


# ==========================================
# VÍDEO E TRANSIÇÃO
# ==========================================

@export_file("*.tscn") var cena_destino: String

@export var video: VideoStreamPlayer
@export var tela_preta: ColorRect

@export var duracao_fade: float = 1.5
@export var duracao_fade_botoes: float = 1.0

var transicionando: bool = false
var finalizando: bool = false
var video_iniciado: bool = false


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:

	botao_play.pressed.connect(iniciar_jogo)
	botao_tutorial.pressed.connect(abrir_tutorial)
	botao_x.pressed.connect(fechar_tutorial)
	botao_skip.pressed.connect(pular_video)

	# Tutorial
	sprite_tutorial.visible = false
	botao_x.visible = false

	# Vídeo
	video.visible = false
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Tela preta
	tela_preta.visible = false
	tela_preta.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Skip
	botao_skip.visible = false
	botao_skip.disabled = true

	video.finished.connect(finalizar_video)

	# Tamanho do vídeo
	video.set_anchors_preset(Control.PRESET_TOP_LEFT)
	video.expand = true

	video.size = Vector2(1152, 648) * 0.95
	video.position = (Vector2(1152, 648) - video.size) / 2


# ==========================================
# ENTER PARA PULAR VÍDEO
# ==========================================

func _input(event: InputEvent) -> void:

	if not video_iniciado or finalizando:
		return

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				pular_video()


# ==========================================
# LISTA DE BOTÕES DO MENU
# ==========================================

func obter_botoes_menu() -> Array[CanvasItem]:
	var elementos: Array[CanvasItem] = []

	if botao_play:
		elementos.append(botao_play)

	if botao_tutorial:
		elementos.append(botao_tutorial)

	for elemento in outros_botoes:
		if elemento != null and not elementos.has(elemento):
			if elemento != botao_skip and elemento != botao_x:
				elementos.append(elemento)

	return elementos


# ==========================================
# BOTÃO PLAY
# ==========================================

func iniciar_jogo() -> void:

	if transicionando:
		return

	transicionando = true

	# Bloqueia todos os botões imediatamente
	for elemento in obter_botoes_menu():
		if elemento is BaseButton:
			elemento.disabled = true
			elemento.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	botao_x.disabled = true
	botao_skip.disabled = true

	get_tree().paused = false

	# Inicia o fade preto
	tela_preta.visible = true
	tela_preta.modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		tela_preta,
		"modulate:a",
		1.0,
		duracao_fade
	)

	# Faz todos os botões desaparecerem
	for botao in obter_botoes_menu():
		tween.tween_property(
			botao,
			"modulate:a",
			0.0,
			duracao_fade_botoes
		)

	await tween.finished

	# Garante que os botões não apareçam
	for botao in obter_botoes_menu():
		botao.visible = false

	# Exibe o vídeo
	video.visible = true
	video.move_to_front()

	# Exibe o Skip
	botao_skip.move_to_front()
	botao_skip.visible = true
	botao_skip.disabled = false
	botao_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	botao_skip.modulate.a = 1.0

	video_iniciado = true
	video.play()


# ==========================================
# FINALIZAR VÍDEO
# ==========================================

func finalizar_video() -> void:

	if finalizando:
		return

	finalizando = true
	video_iniciado = false

	video.stop()
	botao_skip.disabled = true

	if cena_destino != "":
		get_tree().change_scene_to_file(cena_destino)


# ==========================================
# PULAR VÍDEO
# ==========================================

func pular_video() -> void:

	if not video_iniciado:
		return

	finalizar_video()


# ==========================================
# ABRIR TUTORIAL
# ==========================================

func abrir_tutorial() -> void:

	if transicionando:
		return

	sprite_tutorial.visible = true
	botao_x.visible = true
	botao_x.disabled = false

	# Esconde o Play
	botao_play.visible = false
	botao_play.disabled = true

	# Bloqueia os outros botões
	for botao in obter_botoes_menu():
		botao.disabled = true


# ==========================================
# FECHAR TUTORIAL
# ==========================================

func fechar_tutorial() -> void:

	if transicionando:
		return

	sprite_tutorial.visible = false
	botao_x.visible = false

	# Mostra o Play novamente
	botao_play.visible = true
	botao_play.disabled = false

	# Reativa os outros botões
	for botao in obter_botoes_menu():
		botao.disabled = false
