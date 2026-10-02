extends Node3D

var pontos: int = 0
var morto: bool = false

@export_file("*.tscn") var cena_game_over: String   # escolha a cena no Inspector
@export var atraso_troca: float = 1.5

@onready var timer: Timer = $Timer
@onready var label: Label = $TimeLabel

func _ready():
	# conecta por código (só se ainda não estiver conectado no editor)
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	timer.one_shot = true
	timer.start()
	_atualizar_tempo()

func _process(_delta):
	_atualizar_tempo()

func _atualizar_tempo():
	label.text = str(ceil(timer.time_left))

func _on_timer_timeout():
	morrer()

func morrer():
	if morto:
		return
	morto = true
	print("Você morreu!")

	await get_tree().create_timer(atraso_troca).timeout
	get_tree().paused = false   # garante que a próxima cena não nasça pausada
	get_tree().change_scene_to_file(cena_game_over)

func adicionar_tempo(segundos: float) -> void:
	if morto:
		return
	timer.start(timer.time_left + segundos)
