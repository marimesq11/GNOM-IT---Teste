extends CharacterBody3D

@export_group("Partícula de Morte")
@export var controlador_cor_morte: CorMorteGnomo

const GRUPO_ATROPELAVEL := &"atropelavel"

# ==========================================
# CONFIGURAÇÕES
# ==========================================
@export var velocidade: float = 1.3
@export var distancia_pulo: float = 1.0
@export var tempo_pulo: float = 0.5
@export var altura_pulo: float = 1.0
@export var ajuste_altura: float = 0.0
@export var ajuste_frente: float = 0.0
@export var ajuste_lateral: float = 0.0
@export var forca_empurrao: float = 6.0
@export var desaceleracao_empurrao: float = 8.0
@export var dano: float = 3.0
@export var intervalo_dano: float = 1.0
@export var distancia_arremesso: float = 2.0
@export var altura_arremesso: float = 0.6
@export var velocidade_giro_arremesso: float = 8.0
@export var tempo_caido: float = 4.0
@export var mostrar_debug: bool = true
@export var velocidade_rotacao: float = 8.0

# ==========================================
# PATRULHA
# ==========================================
@export_group("Patrulha")
@export var raio_patrulha: float = 4.0
@export var velocidade_patrulha: float = 0.8
@export var espera_patrulha_min: float = 0.5
@export var espera_patrulha_max: float = 2.0
@export var distancia_chegada_patrulha: float = 0.3

var centro_patrulha: Vector3
var destino_patrulha: Vector3
var tempo_espera_patrulha: float = 0.0
var esperando_patrulha: bool = false

# ==========================================
# CONFIGURAÇÕES DOS BARULHINHOS
# ==========================================
@export_group("Barulhinhos")
@export var intervalo_som_min: float = 12.0
@export var intervalo_som_max: float = 25.0
@export var intervalo_global_perseguicao: float = 5.0
@export var pitch_som_min: float = 0.8
@export var pitch_som_max: float = 1.4
@export_range(-40.0, 10.0, 1.0) var volume_perseguicao: float = -8.0

static var proximo_som_perseguicao: float = 0.0
static var ultimo_som_global: int = -1

# ==========================================
# REFERÊNCIAS
# ==========================================
@export_group("Referências")
@export var Cortador: CharacterBody3D
@export var ponto_destino: Marker3D
@onready var colisao: CollisionShape3D = $CollisionShape3D
@onready var ponto_encaixe: Marker3D = $Ponto_Encaixe

@onready var som_barulinho_1: AudioStreamPlayer = $AudioStreamPlayer/Barulinhos
@onready var som_barulinho_2: AudioStreamPlayer = $AudioStreamPlayer/Barulinhos2
@onready var som_barulinho_3: AudioStreamPlayer = $AudioStreamPlayer/Barulinhos3

@export_group("Sons de Morte")
@export var som_morte_gnomo_1: AudioStreamPlayer
@export var som_morte_gnomo_2: AudioStreamPlayer
@export var som_morte_gnomo_3: AudioStreamPlayer
@export var som_morte_gnomo_4: AudioStreamPlayer
@onready var som_morreu: AudioStreamPlayer = $AudioStreamPlayer/Morreu

# ==========================================
# ESTADOS
# ==========================================
enum Estado { PATRULHANDO, PERSEGUINDO, PULANDO, PRESO, CAIDO, ARREMESSADO, MORTO }

var estado: Estado = Estado.PATRULHANDO
var causando_dano: bool = false
var impulso_empurrao: Vector3 = Vector3.ZERO
var _distancia_pulo_quad: float = 0.0
var _inicio_pulo: Vector3 = Vector3.ZERO
var _tempo_pulo_atual: float = 0.0
var _tempo_arremesso: float = 0.0
var _cortador_conectado: CharacterBody3D
var _timer_dano: Timer
var _timer_caido: Timer
var _timer_som_passos: Timer
var _escala_original: Vector3 = Vector3.ONE
var _rotacao_relativa: Quaternion = Quaternion.IDENTITY
var _tempo_debug: float = 0.0

# ==========================================
# READY
# ==========================================
func _ready() -> void:
	_distancia_pulo_quad = distancia_pulo * distancia_pulo
	_escala_original = global_basis.get_scale()
	centro_patrulha = global_position
	_escolher_destino_patrulha()

	_timer_dano = Timer.new()
	_timer_dano.wait_time = intervalo_dano
	_timer_dano.one_shot = false
	_timer_dano.timeout.connect(_tick_dano)
	add_child(_timer_dano)

	_timer_caido = Timer.new()
	_timer_caido.wait_time = tempo_caido
	_timer_caido.one_shot = true
	_timer_caido.timeout.connect(_acabou_tempo_caido)
	add_child(_timer_caido)

	_timer_som_passos = Timer.new()
	_timer_som_passos.one_shot = true
	_timer_som_passos.timeout.connect(_tocar_som_passos)
	add_child(_timer_som_passos)

	som_barulinho_1.volume_db = volume_perseguicao
	som_barulinho_2.volume_db = volume_perseguicao
	som_barulinho_3.volume_db = volume_perseguicao

	_agendar_som_perseguicao()
	_configurar_cortador()

# ==========================================
# SONS
# ==========================================
func _tempo_atual() -> float:
	return Time.get_ticks_msec() / 1000.0

func _agendar_som_perseguicao() -> void:
	if estado != Estado.PERSEGUINDO and estado != Estado.PATRULHANDO:
		return
	var minimo = maxf(intervalo_som_min, 0.1)
	var maximo = maxf(intervalo_som_max, minimo)
	_timer_som_passos.start(randf_range(minimo, maximo))

func _tocar_som_passos() -> void:
	if estado != Estado.PERSEGUINDO and estado != Estado.PATRULHANDO:
		return
	if Vector2(velocity.x, velocity.z).length_squared() < 0.01:
		_agendar_som_perseguicao()
		return

	var agora = _tempo_atual()
	if agora < proximo_som_perseguicao:
		_agendar_som_perseguicao()
		return

	var sons: Array[AudioStreamPlayer] = [som_barulinho_1, som_barulinho_2, som_barulinho_3]
	var indices_disponiveis: Array[int] = []

	for i in range(sons.size()):
		if sons[i] == null or sons[i].stream == null:
			continue
		if i == ultimo_som_global:
			continue
		indices_disponiveis.append(i)

	if indices_disponiveis.is_empty():
		for i in range(sons.size()):
			if sons[i] != null and sons[i].stream != null:
				indices_disponiveis.append(i)

	if indices_disponiveis.is_empty():
		_agendar_som_perseguicao()
		return

	var indice_sorteado: int = indices_disponiveis.pick_random()
	var som_sorteado: AudioStreamPlayer = sons[indice_sorteado]
	var pitch_minimo = maxf(pitch_som_min, 0.01)
	var pitch_maximo = maxf(pitch_som_max, pitch_minimo)

	som_sorteado.pitch_scale = randf_range(pitch_minimo, pitch_maximo)
	som_sorteado.volume_db = volume_perseguicao
	som_sorteado.play()

	ultimo_som_global = indice_sorteado
	proximo_som_perseguicao = agora + maxf(intervalo_global_perseguicao, 0.0)
	_agendar_som_perseguicao()

func _parar_sons_perseguicao() -> void:
	if is_instance_valid(_timer_som_passos):
		_timer_som_passos.stop()
	if som_barulinho_1.playing:
		som_barulinho_1.stop()
	if som_barulinho_2.playing:
		som_barulinho_2.stop()
	if som_barulinho_3.playing:
		som_barulinho_3.stop()

# ==========================================
# CONFIGURAR CORTADOR
# ==========================================
func _configurar_cortador() -> void:
	if not is_instance_valid(Cortador):
		return
	if _cortador_conectado == Cortador:
		return

	_cortador_conectado = Cortador
	add_collision_exception_with(Cortador)
	Cortador.add_collision_exception_with(self)

	if not Cortador.driftou.is_connected(_quando_driftar):
		Cortador.driftou.connect(_quando_driftar)

# ==========================================
# PHYSICS PROCESS
# ==========================================
func _physics_process(delta: float) -> void:
	_configurar_cortador()

	# VERIFICA SE PODE PULAR MESMO DURANTE A PATRULHA
	if estado == Estado.PATRULHANDO or estado == Estado.PERSEGUINDO:
		if is_instance_valid(Cortador) and is_instance_valid(ponto_destino):
			var diferenca: Vector3 = ponto_destino.global_position - global_position
			diferenca.y = 0.0

			var vaga_livre: bool = not is_instance_valid(Cortador.gnomo_em_cima)

			if diferenca.length_squared() <= distancia_pulo * distancia_pulo and vaga_livre:
				estado = Estado.PERSEGUINDO
				esperando_patrulha = false
				comecar_pulo()
				return

	match estado:
		Estado.PATRULHANDO:
			if _jogador_na_area():
				estado = Estado.PERSEGUINDO
				esperando_patrulha = false
				_perseguir(delta)
			else:
				_patrulhar(delta)

		Estado.PERSEGUINDO:
			if not _jogador_na_area():
				estado = Estado.PATRULHANDO
				_escolher_destino_patrulha()
				_patrulhar(delta)
			else:
				_perseguir(delta)

		Estado.PULANDO:
			_atualizar_pulo(delta)

		Estado.PRESO:
			_atualizar_posicao_preso()
			_debug_encaixe(delta)

		Estado.ARREMESSADO:
			_atualizar_arremesso(delta)

# ==========================================
# VERIFICAR ÁREA
# ==========================================
func _jogador_na_area() -> bool:
	if not is_instance_valid(Cortador):
		return false

	var diferenca := Cortador.global_position - global_position
	diferenca.y = 0.0

	return diferenca.length_squared() <= raio_patrulha * raio_patrulha

# ==========================================
# ESCOLHER DESTINO DA PATRULHA
# ==========================================
func _escolher_destino_patrulha() -> void:
	var angulo := randf_range(0.0, TAU)
	var distancia := sqrt(randf()) * maxf(raio_patrulha, 0.0)
	destino_patrulha = centro_patrulha + Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
	esperando_patrulha = false

# ==========================================
# MOVIMENTO DA PATRULHA
# ==========================================
func _patrulhar(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	if esperando_patrulha:
		tempo_espera_patrulha -= delta
		velocity.x = impulso_empurrao.x
		velocity.z = impulso_empurrao.z
		if tempo_espera_patrulha <= 0.0:
			_escolher_destino_patrulha()
	else:
		var diferenca := destino_patrulha - global_position
		diferenca.y = 0.0

		if diferenca.length() <= distancia_chegada_patrulha:
			esperando_patrulha = true
			var minimo := maxf(espera_patrulha_min, 0.0)
			var maximo := maxf(espera_patrulha_max, minimo)
			tempo_espera_patrulha = randf_range(minimo, maximo)
			velocity.x = impulso_empurrao.x
			velocity.z = impulso_empurrao.z
		else:
			var direcao := diferenca.normalized()
			velocity.x = direcao.x * velocidade_patrulha + impulso_empurrao.x
			velocity.z = direcao.z * velocidade_patrulha + impulso_empurrao.z
			_olhar_para_posicao(destino_patrulha, delta)

	impulso_empurrao = impulso_empurrao.move_toward(Vector3.ZERO, desaceleracao_empurrao * delta)
	move_and_slide()

	# ANIMAÇÃO: GnomoAndando
	# $AnimationPlayer.play("GnomoAndando")

# ==========================================
# RECEBER EMPURRÃO
# ==========================================
func receber_empurrao(direcao: Vector3) -> void:
	if estado != Estado.PERSEGUINDO and estado != Estado.PATRULHANDO:
		return
	direcao.y = 0.0
	if direcao.length_squared() < 0.001:
		return
	impulso_empurrao = direcao.normalized() * forca_empurrao

# ==========================================
# PERSEGUIÇÃO
# ==========================================
func _perseguir(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	if not is_instance_valid(Cortador):
		velocity.x = impulso_empurrao.x
		velocity.z = impulso_empurrao.z
		impulso_empurrao = impulso_empurrao.move_toward(Vector3.ZERO, desaceleracao_empurrao * delta)
		move_and_slide()
		return

	var posicao_alvo: Vector3 = Cortador.global_position

	if is_instance_valid(ponto_destino):
		posicao_alvo = ponto_destino.global_position

	var diferenca := posicao_alvo - global_position
	diferenca.y = 0.0
	var distancia_quadrada := diferenca.length_squared()

	var vaga_livre: bool = not is_instance_valid(Cortador.gnomo_em_cima)

	# VERIFICA SE PODE PULAR
	if distancia_quadrada <= distancia_pulo * distancia_pulo and vaga_livre:
		if is_on_floor():
			if mostrar_debug:
				print("GNOMO: iniciando pulo!")
			comecar_pulo()
			return

	var direcao := Vector3.ZERO
	if distancia_quadrada > 0.0001:
		direcao = diferenca.normalized()

	velocity.x = direcao.x * velocidade + impulso_empurrao.x
	velocity.z = direcao.z * velocidade + impulso_empurrao.z

	impulso_empurrao = impulso_empurrao.move_toward(Vector3.ZERO, desaceleracao_empurrao * delta)

	move_and_slide()

	# VERIFICA NOVAMENTE APÓS O MOVIMENTO
	if estado == Estado.PERSEGUINDO and vaga_livre and is_on_floor():
		var nova_diferenca := posicao_alvo - global_position
		nova_diferenca.y = 0.0

		if nova_diferenca.length_squared() <= distancia_pulo * distancia_pulo:
			if mostrar_debug:
				print("GNOMO: iniciando pulo após movimento!")
			comecar_pulo()
			return

	# ANIMAÇÃO: GnomoAndando
	# $AnimationPlayer.play("GnomoAndando")

	_olhar_para_jogador(delta)

# ==========================================
# POSIÇÃO DO ALVO
# ==========================================
func _obter_posicao_alvo() -> Vector3:
	var ajuste_local := Vector3(ajuste_lateral, ajuste_altura, ajuste_frente)
	var base_cortador := Cortador.global_basis.orthonormalized()
	return ponto_destino.global_position + base_cortador * ajuste_local

func _calcular_posicao_encaixe() -> Vector3:
	var deslocamento := ponto_encaixe.global_position - global_position
	return _obter_posicao_alvo() - deslocamento

# ==========================================
# INÍCIO DO PULO
# ==========================================
func comecar_pulo() -> void:
	if estado != Estado.PERSEGUINDO:
		return
	if not is_instance_valid(Cortador) or not is_instance_valid(ponto_destino):
		return
	if is_instance_valid(Cortador.gnomo_em_cima):
		return

	Cortador.gnomo_em_cima = self
	estado = Estado.PULANDO
	velocity = Vector3.ZERO
	impulso_empurrao = Vector3.ZERO
	_inicio_pulo = global_position
	_tempo_pulo_atual = 0.0

	var rotacao_cortador := Cortador.global_basis.orthonormalized().get_rotation_quaternion()
	var rotacao_gnomo := global_basis.orthonormalized().get_rotation_quaternion()
	_rotacao_relativa = rotacao_cortador.inverse() * rotacao_gnomo

	_parar_sons_perseguicao()
	colisao.set_deferred("disabled", true)

# ==========================================
# MOVIMENTO DO PULO
# ==========================================
func _atualizar_pulo(delta: float) -> void:
	if not is_instance_valid(Cortador) or not is_instance_valid(ponto_destino):
		liberar_vaga()
		estado = Estado.PATRULHANDO
		_escolher_destino_patrulha()
		colisao.set_deferred("disabled", false)
		_agendar_som_perseguicao()
		return

	_tempo_pulo_atual += delta
	var progresso := clampf(_tempo_pulo_atual / maxf(tempo_pulo, 0.001), 0.0, 1.0)
	var rotacao_cortador := Cortador.global_basis.orthonormalized().get_rotation_quaternion()
	var nova_rotacao := rotacao_cortador * _rotacao_relativa
	global_basis = Basis(nova_rotacao).scaled(_escala_original)

	var destino := _calcular_posicao_encaixe()
	var nova_posicao := _inicio_pulo.lerp(destino, progresso)
	nova_posicao.y += sin(progresso * PI) * altura_pulo
	global_position = nova_posicao

	if progresso >= 1.0:
		ficar_no_cortador()

# ==========================================
# PRESO NO CORTADOR
# ==========================================
func ficar_no_cortador() -> void:
	if estado != Estado.PULANDO:
		return

	estado = Estado.PRESO
	velocity = Vector3.ZERO
	impulso_empurrao = Vector3.ZERO
	colisao.set_deferred("disabled", true)
	_atualizar_posicao_preso()
	causando_dano = true
	_tempo_debug = 0.0

	# PARTÍCULA: ParticulaRoubandoGasolina
	# $ParticulaRoubandoGasolina.emitting = true
	dano_continuo()

func _atualizar_posicao_preso() -> void:
	if not is_instance_valid(Cortador) or not is_instance_valid(ponto_destino):
		return

	var rotacao_cortador := Cortador.global_basis.orthonormalized().get_rotation_quaternion()
	var nova_rotacao := rotacao_cortador * _rotacao_relativa
	global_basis = Basis(nova_rotacao).scaled(_escala_original)
	global_position = _calcular_posicao_encaixe()

func _debug_encaixe(delta: float) -> void:
	if not mostrar_debug:
		return
	_tempo_debug += delta
	if _tempo_debug < 1.0:
		return

	_tempo_debug = 0.0
	print("========== ENCAIXE DO GNOMO ==========")
	print("Ponto do gnomo: ", ponto_encaixe.global_position)
	print("Ponto do cortador: ", ponto_destino.global_position)
	print("Distância: ", ponto_encaixe.global_position.distance_to(ponto_destino.global_position))
	print("Posição do gnomo: ", global_position)
	print("Escala do gnomo: ", global_basis.get_scale())
	print("Ajustes: ", Vector3(ajuste_lateral, ajuste_altura, ajuste_frente))
	print("======================================")

# ==========================================
# DANO CONTÍNUO
# ==========================================
func dano_continuo() -> void:
	_tick_dano()
	if causando_dano and estado == Estado.PRESO:
		_timer_dano.start()

func _tick_dano() -> void:
	if not causando_dano or estado != Estado.PRESO:
		_timer_dano.stop()
		return
	if not is_instance_valid(Cortador):
		_timer_dano.stop()
		return
	Cortador.tomar_dano(dano)

# ==========================================
# DRIFT
# ==========================================
func _quando_driftar(direcao_drift: Vector3) -> void:
	if estado != Estado.PRESO:
		return
	cair_do_cortador(direcao_drift)

# ==========================================
# ARREMESSO
# ==========================================
func cair_do_cortador(direcao_drift: Vector3) -> void:
	if estado != Estado.PRESO:
		return

	estado = Estado.ARREMESSADO
	causando_dano = false
	_timer_dano.stop()

	# PARTÍCULA: ParticulaRoubandoGasolina
	# $ParticulaRoubandoGasolina.emitting = false

	liberar_vaga()
	colisao.set_deferred("disabled", false)
	rotation.x = 0.0
	rotation.z = 0.0

	var lado := Vector3(-direcao_drift.z, 0.0, direcao_drift.x)
	if lado.length_squared() > 0.0001:
		lado = lado.normalized()
	else:
		lado = Vector3.RIGHT

	var g := maxf(get_gravity().length(), 0.01)
	var v0 := sqrt(2.0 * g * altura_arremesso)
	var tempo_voo := maxf(2.0 * v0 / g, 0.05)
	velocity = lado * (distancia_arremesso / tempo_voo)
	velocity.y = v0
	_tempo_arremesso = 0.0

func _atualizar_arremesso(delta: float) -> void:
	_tempo_arremesso += delta
	velocity += get_gravity() * delta
	rotation.x += velocidade_giro_arremesso * delta
	move_and_slide()

	if _tempo_arremesso > 0.1 and is_on_floor():
		ficar_caido()

# ==========================================
# CAÍDO
# ==========================================
func ficar_caido() -> void:
	if estado != Estado.ARREMESSADO:
		return

	estado = Estado.CAIDO
	velocity = Vector3.ZERO
	impulso_empurrao = Vector3.ZERO
	rotation.x = deg_to_rad(90.0)
	rotation.z = 0.0
	move_and_collide(Vector3.DOWN * 0.2)

	if not is_in_group(GRUPO_ATROPELAVEL):
		add_to_group(GRUPO_ATROPELAVEL)

	_timer_caido.start()

func _acabou_tempo_caido() -> void:
	if estado == Estado.CAIDO:
		levantar()

func levantar() -> void:
	if estado != Estado.CAIDO:
		return

	_timer_caido.stop()
	if is_in_group(GRUPO_ATROPELAVEL):
		remove_from_group(GRUPO_ATROPELAVEL)

	rotation.x = 0.0
	rotation.z = 0.0
	estado = Estado.PATRULHANDO
	velocity = Vector3.ZERO
	impulso_empurrao = Vector3.ZERO
	_escolher_destino_patrulha()
	_agendar_som_perseguicao()

# ==========================================
# LIBERAR VAGA
# ==========================================
func liberar_vaga() -> void:
	if not is_instance_valid(Cortador):
		return
	if Cortador.gnomo_em_cima == self:
		Cortador.gnomo_em_cima = null

# ==========================================
# MORTE
# ==========================================
func morrer_atropelado() -> void:
	if estado != Estado.CAIDO:
		return

	GameManager.adicionar_pontos(50, global_position)
	GameManager.registrar_gnomo()
	estado = Estado.MORTO
	causando_dano = false
	_timer_dano.stop()
	_timer_caido.stop()
	_parar_sons_perseguicao()
	
	if is_instance_valid(controlador_cor_morte):
		controlador_cor_morte.mudar_cor(self)

	if is_in_group(GRUPO_ATROPELAVEL):
		remove_from_group(GRUPO_ATROPELAVEL)

	liberar_vaga()

	# ANIMAÇÃO: PARAR GnomoAndando
	# $AnimationPlayer.stop()

	# PARTÍCULA: ParticulaMorte
	# $ParticulaMorte.emitting = true

	var sons_morte: Array[AudioStreamPlayer] = [
		som_morte_gnomo_1,
		som_morte_gnomo_2,
		som_morte_gnomo_3,
		som_morte_gnomo_4
	]

	sons_morte = sons_morte.filter(func(som): return som != null and som.stream != null)

	if not sons_morte.is_empty():
		var som_sorteado: AudioStreamPlayer = sons_morte.pick_random()
		som_morreu.stream = som_sorteado.stream
		som_morreu.play()
	else:
		push_warning("Nenhum som de morte configurado no gnomo!")

	hide()
	colisao.set_deferred("disabled", true)
	set_physics_process(false)

	if som_morreu.playing:
		await som_morreu.finished

	queue_free()

# ==========================================
# OLHAR PARA UMA POSIÇÃO
# ==========================================
func _olhar_para_posicao(posicao: Vector3, delta: float) -> void:
	var direcao := posicao - global_position
	direcao.y = 0.0
	if direcao.length_squared() < 0.001:
		return

	var angulo_alvo := atan2(direcao.x, direcao.z) - PI / 2.0
	rotation.y = lerp_angle(rotation.y, angulo_alvo, clampf(velocidade_rotacao * delta, 0.0, 1.0))

func _olhar_para_jogador(delta: float) -> void:
	if not is_instance_valid(Cortador):
		return
	_olhar_para_posicao(Cortador.global_position, delta)
