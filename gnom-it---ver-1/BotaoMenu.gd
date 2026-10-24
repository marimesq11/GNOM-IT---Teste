
extends Button

@export_file("*.tscn") var cena_destino: String

@export var video: VideoStreamPlayer
@export var tela_preta: ColorRect
@export var botao_skip: Button
@export var TutorialBotao: Button

@export var duracao_fade: float = 1.5

var transicionando: bool = false
var finalizando: bool = false


func _ready() -> void:
	if video == null or tela_preta == null or botao_skip == null:
		return

	pressed.connect(_on_pressed)
	botao_skip.pressed.connect(pular_video)

	video.visible = false
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE

	tela_preta.visible = false
	tela_preta.mouse_filter = Control.MOUSE_FILTER_IGNORE

	botao_skip.visible = false

	video.finished.connect(finalizar_video)

	# Configura o vídeo
	video.set_anchors_preset(Control.PRESET_TOP_LEFT)
	video.expand = true

	video.size = Vector2(1152, 648) * 0.95

	video.position = (Vector2(1152, 648) - video.size) / 2

func _on_pressed() -> void:
	if transicionando:
		return

	transicionando = true
	disabled = true
	
	if TutorialBotao != null:
		TutorialBotao.disabled = true

	get_tree().paused = false

	# Começa a escurecer a tela
	tela_preta.visible = true
	tela_preta.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(
		tela_preta,
		"modulate:a",
		1.0,
		duracao_fade
	)

	await tween.finished

	# Exibe o vídeo sobre a tela preta
	video.visible = true
	video.move_to_front()

	# Mantém o botão Skip acima do vídeo
	botao_skip.move_to_front()
	botao_skip.visible = true

	# Reproduz o vídeo
	video.play()


func finalizar_video() -> void:
	if finalizando:
		return

	finalizando = true

	video.stop()
	botao_skip.disabled = true

	if cena_destino != "":
		get_tree().change_scene_to_file(cena_destino)


func pular_video() -> void:
	finalizar_video()
