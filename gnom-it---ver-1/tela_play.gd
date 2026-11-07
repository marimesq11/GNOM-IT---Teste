
extends Node2D

# ==========================================
# BOTÕES
# ==========================================

@export var botao_play: Button
@export var botao_tutorial: Button
@export var botao_x: Button
@export var botao_skip: Button
@export var outros_botoes: Array[CanvasItem]

# ==========================================
# TUTORIAL
# ==========================================

@export var sprite_tutorial: Sprite2D
@export var tela_fundo: CanvasItem

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
# CRÉDITOS
# ==========================================

@export var botao_creditos: Button
@export var botao_sair: Button
@export var fundo_creditos: TextureRect
@export var texto_creditos: RichTextLabel
@export var velocidade_creditos: float = 35.0

var creditos_abertos: bool = false
var tween_creditos: Tween
var elementos_escondidos: Array[CanvasItem] = []

# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:
	botao_play.pressed.connect(iniciar_jogo)
	botao_tutorial.pressed.connect(abrir_tutorial)
	botao_x.pressed.connect(fechar_tutorial)
	botao_skip.pressed.connect(pular_video)
	botao_creditos.pressed.connect(abrir_creditos)
	botao_sair.pressed.connect(sair_jogo)
	video.finished.connect(finalizar_video)

	# Tutorial
	sprite_tutorial.visible = false
	tela_fundo.visible = false
	botao_x.visible = false

	if tela_fundo is Control:
		tela_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Créditos
	fundo_creditos.visible = false
	texto_creditos.visible = false
	fundo_creditos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto_creditos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto_creditos.scroll_active = false

	# Vídeo
	video.visible = false
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Tela preta
	tela_preta.visible = false
	tela_preta.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Skip
	botao_skip.visible = false
	botao_skip.disabled = true

	# Tamanho do vídeo
	video.set_anchors_preset(Control.PRESET_TOP_LEFT)
	video.expand = true
	video.size = Vector2(1152, 648) * 0.95
	video.position = (Vector2(1152, 648) - video.size) / 2.0

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
# ELEMENTOS DO MENU
# ==========================================

func obter_botoes_menu() -> Array[CanvasItem]:
	var elementos: Array[CanvasItem] = []

	for elemento in [botao_play, botao_tutorial, botao_creditos, botao_sair]:
		if elemento != null and not elementos.has(elemento):
			elementos.append(elemento)

	for elemento in outros_botoes:
		if elemento != null and not elementos.has(elemento):
			if elemento != botao_skip and elemento != botao_x:
				if elemento != fundo_creditos and elemento != texto_creditos:
					elementos.append(elemento)

	return elementos

# ==========================================
# BOTÃO PLAY
# ==========================================

func iniciar_jogo() -> void:
	if transicionando or creditos_abertos:
		return

	transicionando = true

	# Bloqueia os botões
	for elemento in obter_botoes_menu():
		if elemento is BaseButton:
			elemento.disabled = true
			elemento.mouse_filter = Control.MOUSE_FILTER_IGNORE

	botao_x.disabled = true
	botao_skip.disabled = true
	get_tree().paused = false

	# Inicia a transição
	tela_preta.visible = true
	tela_preta.modulate.a = 0.0
	tela_preta.move_to_front()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(tela_preta, "modulate:a", 1.0, duracao_fade)

	for elemento in obter_botoes_menu():
		tween.tween_property(elemento, "modulate:a", 0.0, duracao_fade_botoes)

	await tween.finished

	# Esconde o menu
	for elemento in obter_botoes_menu():
		elemento.visible = false

	# Mostra o vídeo
	video.visible = true
	video.move_to_front()

	# Mostra o Skip
	botao_skip.visible = true
	botao_skip.disabled = false
	botao_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	botao_skip.modulate.a = 1.0
	botao_skip.move_to_front()

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
	if transicionando or creditos_abertos:
		return

	tela_fundo.visible = true
	sprite_tutorial.visible = true
	botao_x.visible = true

	botao_play.visible = false
	botao_play.disabled = true

	for elemento in obter_botoes_menu():
		if elemento is BaseButton:
			elemento.disabled = true

	botao_x.disabled = false
	botao_x.mouse_filter = Control.MOUSE_FILTER_STOP
	botao_x.move_to_front()

# ==========================================
# FECHAR TUTORIAL
# ==========================================

func fechar_tutorial() -> void:
	if transicionando:
		return

	tela_fundo.visible = false
	sprite_tutorial.visible = false
	botao_x.visible = false
	botao_play.visible = true

	for elemento in obter_botoes_menu():
		if elemento is BaseButton:
			elemento.disabled = false

# ==========================================
# ABRIR CRÉDITOS
# ==========================================

func abrir_creditos() -> void:
	if transicionando or creditos_abertos:
		return

	creditos_abertos = true
	elementos_escondidos.clear()

	# Esconde todos os elementos do menu
	for elemento in obter_botoes_menu():
		if elemento.visible:
			elementos_escondidos.append(elemento)
			elemento.visible = false

	# Mostra o fundo e o texto
	fundo_creditos.visible = true
	texto_creditos.visible = true
	fundo_creditos.move_to_front()
	texto_creditos.move_to_front()

	# Usa o texto já configurado no Inspector
	texto_creditos.scroll_active = false
	texto_creditos.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Calcula a altura real do conteúdo
	var altura_tela: float = get_viewport_rect().size.y
	var altura_texto: float = maxf(texto_creditos.get_content_height(), texto_creditos.size.y)

	# Começa abaixo da tela
	texto_creditos.global_position.y = altura_tela

	# Termina acima da tela
	var posicao_final: float = -altura_texto
	var distancia: float = altura_tela + altura_texto
	var duracao: float = distancia / maxf(velocidade_creditos, 1.0)

	# Cancela animação anterior
	if tween_creditos and tween_creditos.is_running():
		tween_creditos.kill()

	# Faz o texto subir
	tween_creditos = create_tween()
	tween_creditos.tween_property(texto_creditos, "global_position:y", posicao_final, duracao)

	# Fecha automaticamente
	tween_creditos.finished.connect(fechar_creditos)

# ==========================================
# FECHAR CRÉDITOS AUTOMATICAMENTE
# ==========================================

func fechar_creditos() -> void:
	if not creditos_abertos:
		return

	creditos_abertos = false
	fundo_creditos.visible = false
	texto_creditos.visible = false

	# Restaura o menu
	for elemento in elementos_escondidos:
		if is_instance_valid(elemento):
			elemento.visible = true

	elementos_escondidos.clear()

# ==========================================
# SAIR DO JOGO
# ==========================================

func sair_jogo() -> void:
	get_tree().quit()
