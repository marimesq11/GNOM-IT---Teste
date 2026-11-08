extends Node3D

var pontos: int = 0
var morto: bool = false

@export_file("*.tscn") var cena_game_over: String
@export var atraso_troca: float = 1.5

@export_group("Alerta do timer")
@export var limite_alerta: float = 15.0
@export var intensidade_tremor: float = 4.0
@export var cor_normal: Color = Color.ORANGE
@export var cor_alerta: Color = Color.RED

@export_group("Som de tempo acabando")
@export var limite_som: float = 15.0
@export var som_tempo_acabando: AudioStreamPlayer

@onready var timer: Timer = $Timer
@onready var label: Label = $TimeLabel

var posicao_original_label: Vector2

func _ready():
	GameManager.reiniciar()
	posicao_original_label = label.position
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	timer.one_shot = true
	timer.start()
	_atualizar_tempo()

func _process(_delta):
	_atualizar_tempo()
	_efeito_alerta()
	_verificar_som_tempo()

func _atualizar_tempo():
	label.text = str(int(ceil(timer.time_left)))

func _efeito_alerta():
	var restante := timer.time_left

	if morto or timer.is_stopped() or restante > limite_alerta:
		label.position = posicao_original_label
		label.add_theme_color_override("font_color", cor_normal)
		return

	var forca := 1.0 - (restante / limite_alerta)
	label.add_theme_color_override("font_color", cor_normal.lerp(cor_alerta, forca))

	var tremor := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	label.position = posicao_original_label + tremor * intensidade_tremor * (0.5 + forca)

func _verificar_som_tempo():
	if som_tempo_acabando == null:
		return

	if morto or timer.is_stopped():
		if som_tempo_acabando.playing:
			som_tempo_acabando.stop()
		return

	if timer.time_left < limite_som:
		if not som_tempo_acabando.playing:
			som_tempo_acabando.play()
	else:
		if som_tempo_acabando.playing:
			som_tempo_acabando.stop()

func _on_timer_timeout():
	morrer()

func morrer():
	if morto:
		return

	morto = true
	label.position = posicao_original_label
	label.add_theme_color_override("font_color", cor_alerta)

	if som_tempo_acabando:
		som_tempo_acabando.stop()

	print("Você morreu!")

	await get_tree().create_timer(atraso_troca).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file(cena_game_over)

func adicionar_tempo(segundos: float) -> void:
	if morto:
		return

	timer.start(timer.time_left + segundos)
	_verificar_som_tempo()
