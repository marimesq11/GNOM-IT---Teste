
extends Node3D

var pontos: int = 0
var morto: bool = false
var transicao_ativa: bool = false

@export_file("*.tscn") var cena_game_over: String
@export var atraso_troca: float = 1.5

# ==================================================
# ALERTA DO TIMER
# ==================================================

@export_group("Alerta do timer")
@export var limite_alerta: float = 15.0
@export var intensidade_tremor: float = 4.0
@export var cor_normal: Color = Color.ORANGE
@export var cor_alerta: Color = Color.RED

# ==================================================
# SOM DO TIMER
# ==================================================

@export_group("Som de tempo acabando")
@export var limite_som: float = 10.0
@export var som_tempo_acabando: AudioStreamPlayer

# ==================================================
# CAMERA DE DERROTA
# ==================================================

@export_group("Camera de Derrota")
@export var camera_derrota: Camera3D
@export var centro_da_fase: Marker3D

@export var altura_camera: float = 22.0
@export var distancia_camera: float = 18.0

@export var tempo_subida: float = 2.0
@export var tempo_volta: float = 5.0
@export var tempo_retorno: float = 2.0

@export var distancia_zoom: float = 4.0
@export var altura_zoom: float = 2.5

# ==================================================
# VINHETA
# ==================================================

@export_group("Transicao de Vinheta")
@export var tempo_fechar: float = 0.7
@export var tempo_escuro: float = 1.0
@export var tempo_abrir: float = 0.7

# ==================================================
# REFERENCIAS
# ==================================================

@onready var timer: Timer = $Timer
@onready var label: Label = $TimeLabel

var posicao_original_label: Vector2

var jogador: Node3D
var angulo_inicial: float = 0.0
var inicio_movimento: Vector3
var destino_movimento: Vector3

# ==================================================
# READY
# ==================================================

func _ready() -> void:
	# Main e seus filhos respeitam a pausa
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Garante que a fase comece despausada
	get_tree().paused = false

	GameManager.reiniciar()

	posicao_original_label = label.position

	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	timer.one_shot = true
	timer.start()

	_atualizar_tempo()

	# Encontra o jogador
	jogador = get_tree().get_first_node_in_group("player") as Node3D

	# Conecta o sinal de morte do cortador
	if jogador and jogador.has_signal("morreu"):
		if not jogador.morreu.is_connected(_on_jogador_morreu):
			jogador.morreu.connect(_on_jogador_morreu)

	# Mantem a camera de derrota desligada
	if camera_derrota:
		camera_derrota.current = false


# ==================================================
# PROCESS
# ==================================================

func _process(_delta: float) -> void:
	_atualizar_tempo()
	_efeito_alerta()
	_verificar_som_tempo()


# ==================================================
# ATUALIZAR TEMPO
# ==================================================

func _atualizar_tempo() -> void:
	label.text = str(int(ceil(timer.time_left)))


# ==================================================
# EFEITO DE ALERTA
# ==================================================

func _efeito_alerta() -> void:
	var restante := timer.time_left

	if morto or timer.is_stopped() or restante > limite_alerta:
		label.position = posicao_original_label
		label.add_theme_color_override("font_color", cor_normal)
		return

	var forca := 1.0 - (restante / limite_alerta)

	label.add_theme_color_override(
		"font_color",
		cor_normal.lerp(cor_alerta, forca)
	)

	var tremor := Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)

	label.position = posicao_original_label + tremor * intensidade_tremor * (0.5 + forca)


# ==================================================
# SOM DO TEMPO ACABANDO
# ==================================================

func _verificar_som_tempo() -> void:
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


# ==================================================
# FIM DO TIMER
# ==================================================

func _on_timer_timeout() -> void:
	morrer()


# ==================================================
# MORTE DO JOGADOR
# ==================================================

func _on_jogador_morreu() -> void:
	morrer()


# ==================================================
# MORRER E CONGELAR A FASE
# ==================================================

func morrer() -> void:
	if morto:
		return

	morto = true

	# Para o cronometro
	timer.stop()

	label.position = posicao_original_label
	label.add_theme_color_override("font_color", cor_alerta)

	# Para o som do timer
	if som_tempo_acabando:
		som_tempo_acabando.stop()

	# Trava o cortador
	if is_instance_valid(jogador):
		if jogador.has_method("travar_movimento"):
			jogador.travar_movimento()

	print("Fim da partida!")

	# Congela a fase inteira
	get_tree().paused = true

	print("JOGO PAUSADO: ", get_tree().paused)

	# Espera mesmo com o jogo pausado
	await get_tree().create_timer(
		atraso_troca,
		true
	).timeout

	# Inicia a camera cinematografica
	iniciar_camera_derrota()


# ==================================================
# ADICIONAR TEMPO
# ==================================================

func adicionar_tempo(segundos: float) -> void:
	if morto:
		return

	timer.start(timer.time_left + segundos)
	_verificar_som_tempo()


# ==================================================
# CAMERA CINEMATOGRAFICA
# ==================================================

func iniciar_camera_derrota() -> void:
	if not camera_derrota or not centro_da_fase or not jogador:
		iniciar_transicao(cena_game_over)
		return

	# Guarda a camera atual
	var camera_original = get_viewport().get_camera_3d()

	if camera_original:
		camera_derrota.global_transform = camera_original.global_transform

	# Ativa a CameraFinalFase
	camera_derrota.make_current()

	var centro = centro_da_fase.global_position

	# Calcula o angulo inicial
	var diferenca = camera_derrota.global_position - centro
	angulo_inicial = atan2(diferenca.x, diferenca.z)

	# ==================================================
	# ETAPA 1 - SUBIR E AFASTAR
	# ==================================================

	inicio_movimento = camera_derrota.global_position

	destino_movimento = centro + Vector3(
		sin(angulo_inicial) * distancia_camera,
		altura_camera,
		cos(angulo_inicial) * distancia_camera
	)

	var subida = create_tween()
	subida.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	subida.set_trans(Tween.TRANS_SINE)
	subida.set_ease(Tween.EASE_IN_OUT)

	subida.tween_method(
		_atualizar_subida,
		0.0,
		1.0,
		tempo_subida
	)

	await subida.finished

	# ==================================================
	# ETAPA 2 - GIRAR AO REDOR DA FASE
	# ==================================================

	var volta = create_tween()
	volta.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	volta.set_trans(Tween.TRANS_LINEAR)

	volta.tween_method(
		_atualizar_orbita,
		0.0,
		TAU,
		tempo_volta
	)

	await volta.finished

	# ==================================================
	# ETAPA 3 - APROXIMAR DO JOGADOR
	# ==================================================

	inicio_movimento = camera_derrota.global_position

	destino_movimento = jogador.global_position + Vector3(
		sin(angulo_inicial) * distancia_zoom,
		altura_zoom,
		cos(angulo_inicial) * distancia_zoom
	)

	var retorno = create_tween()
	retorno.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	retorno.set_trans(Tween.TRANS_SINE)
	retorno.set_ease(Tween.EASE_IN_OUT)

	retorno.tween_method(
		_atualizar_retorno,
		0.0,
		1.0,
		tempo_retorno
	)

	await retorno.finished

	# ==================================================
	# ETAPA 4 - VINHETA
	# ==================================================

	iniciar_transicao(cena_game_over)


# ==================================================
# MOVIMENTO DE SUBIDA
# ==================================================

func _atualizar_subida(valor: float) -> void:
	camera_derrota.global_position = inicio_movimento.lerp(
		destino_movimento,
		valor
	)

	camera_derrota.look_at(
		centro_da_fase.global_position,
		Vector3.UP
	)


# ==================================================
# MOVIMENTO CIRCULAR
# ==================================================

func _atualizar_orbita(valor: float) -> void:
	var angulo = angulo_inicial + valor
	var centro = centro_da_fase.global_position

	camera_derrota.global_position = centro + Vector3(
		sin(angulo) * distancia_camera,
		altura_camera,
		cos(angulo) * distancia_camera
	)

	camera_derrota.look_at(
		centro,
		Vector3.UP
	)


# ==================================================
# MOVIMENTO DE RETORNO
# ==================================================

func _atualizar_retorno(valor: float) -> void:
	camera_derrota.global_position = inicio_movimento.lerp(
		destino_movimento,
		valor
	)

	camera_derrota.look_at(
		jogador.global_position + Vector3(0.0, 1.0, 0.0),
		Vector3.UP
	)


# ==================================================
# TRANSICAO DE VINHETA
# ==================================================

func iniciar_transicao(cena_destino: String) -> void:
	if transicao_ativa:
		return

	transicao_ativa = true

	# Guarda a arvore antes da troca de cena
	var arvore = get_tree()

	# Cria uma camada que sobrevive a troca de cena
	var camada = CanvasLayer.new()
	camada.layer = 100
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	arvore.root.add_child(camada)

	# Cria a vinheta
	var vinheta = ColorRect.new()
	camada.add_child(vinheta)

	vinheta.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vinheta.color = Color.WHITE

	# Aplica o shader
	var material = ShaderMaterial.new()
	material.shader = preload("res://Shaders/VinhetaMorte.gdshader")

	vinheta.material = material
	material.set_shader_parameter("raio", 1.4)

	# Cria o Tween independente do Main
	var animacao = arvore.create_tween()
	animacao.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# Fecha a vinheta
	animacao.tween_property(
		material,
		"shader_parameter/raio",
		-0.2,
		tempo_fechar
	)

	# Mantem a tela preta
	animacao.tween_interval(tempo_escuro)

	# Despausa antes da troca
	animacao.tween_callback(
		arvore.set.bind("paused", false)
	)

	# Troca de cena
	animacao.tween_callback(
		arvore.change_scene_to_file.bind(cena_destino)
	)

	# Pequeno intervalo para carregar
	animacao.tween_interval(0.1)

	# Abre a vinheta
	animacao.tween_property(
		material,
		"shader_parameter/raio",
		1.4,
		tempo_abrir
	)

	# Remove a camada
	animacao.tween_callback(camada.queue_free)
