extends CharacterBody3D

const GRUPO_ATROPELAVEL := &"atropelavel"

# MOVIMENTO
@export var velocidade: float = 1.3
@export var distancia_pulo: float = 1.0
@export var tempo_pulo: float = 0.5
@export var altura_pulo: float = 1.0

# DANO
@export var dano: float = 2.0
@export var intervalo_dano: float = 1.0

# QUEDA / ARREMESSO
## Distância horizontal aproximada do arremesso.
@export var distancia_arremesso: float = 2.0
## Altura do ponto mais alto do arco do arremesso.
@export var altura_arremesso: float = 0.6
## Velocidade do giro enquanto voa (rad/s).
@export var velocidade_giro_arremesso: float = 8.0
@export var tempo_caido: float = 4.0

# REFERÊNCIAS
@onready var Cortador: CharacterBody3D = %cortador
@export var ponto_destino: Marker3D
@onready var colisao: CollisionShape3D = $CollisionShape3D

# ARREMESSADO = voando/caindo com gravidade até tocar o chão
enum Estado {PERSEGUINDO, PULANDO, PRESO, CAIDO, ARREMESSADO}
var estado: Estado = Estado.PERSEGUINDO

var causando_dano: bool = false
var pai_original: Node

var _distancia_pulo_quad := 0.0
var _inicio_pulo := Vector3.ZERO
var _tempo_pulo_atual := 0.0
var _tempo_arremesso := 0.0
var _timer_dano: Timer
var _timer_caido: Timer


func _ready() -> void:
	pai_original = get_parent()
	_distancia_pulo_quad = distancia_pulo * distancia_pulo

	# Timers reaproveitados (em vez de criar um create_timer novo a cada uso)
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

	# _process só liga durante o pulo; _physics_process só quando precisa de física
	set_process(false)

	if is_instance_valid(Cortador):
		Cortador.driftou.connect(_quando_driftar)


func _physics_process(delta: float) -> void:
	if estado == Estado.PERSEGUINDO:
		_perseguir(delta)
	elif estado == Estado.ARREMESSADO:
		_atualizar_arremesso(delta)


# ---------------------------------------------------------
# PERSEGUIÇÃO (com gravidade)
# ---------------------------------------------------------

func _perseguir(delta: float) -> void:
	# Gravidade: cai até tocar o chão e fica no chão
	if not is_on_floor():
		velocity += get_gravity() * delta

	if not is_instance_valid(Cortador) or not is_instance_valid(ponto_destino):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var diferenca := Cortador.global_position - global_position
	diferenca.y = 0.0

	var distancia_quadrada := diferenca.length_squared()

	# Só pula quando já está no chão (se acabou de nascer no ar, espera pousar)
	if distancia_quadrada <= _distancia_pulo_quad and is_on_floor():
		comecar_pulo()
		return

	if distancia_quadrada <= 0.0001:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var direcao := diferenca.normalized()

	velocity.x = direcao.x * velocidade
	velocity.z = direcao.z * velocidade

	move_and_slide()

	rotation.y = atan2(direcao.x, direcao.z) + PI / 2


# ---------------------------------------------------------
# PULO ATÉ O CORTADOR (por _process, suave em qualquer FPS)
# ---------------------------------------------------------

func comecar_pulo() -> void:
	if estado != Estado.PERSEGUINDO:
		return

	estado = Estado.PULANDO
	velocity = Vector3.ZERO
	pular_para_cortador()


func pular_para_cortador() -> void:
	_inicio_pulo = global_position
	_tempo_pulo_atual = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if estado != Estado.PULANDO:
		set_process(false)
		return

	if not is_instance_valid(Cortador) or not is_instance_valid(ponto_destino):
		# Alvo sumiu: volta a perseguir em vez de ficar travado no ar
		estado = Estado.PERSEGUINDO
		set_process(false)
		return

	_tempo_pulo_atual += delta

	var progresso := clampf(_tempo_pulo_atual / maxf(tempo_pulo, 0.001), 0.0, 1.0)
	var nova_posicao := _inicio_pulo.lerp(ponto_destino.global_position, progresso)
	nova_posicao.y += sin(progresso * PI) * altura_pulo
	global_position = nova_posicao

	if progresso >= 1.0:
		set_process(false)
		ficar_no_cortador()


func ficar_no_cortador() -> void:
	if estado != Estado.PULANDO:
		return

	estado = Estado.PRESO
	velocity = Vector3.ZERO

	colisao.set_deferred("disabled", true)

	# Fica preso ao Marker do cortador
	reparent(ponto_destino, true)
	position = Vector3.ZERO

	# Não precisa calcular nada de física enquanto está preso
	set_physics_process(false)

	causando_dano = true
	dano_continuo()


# ---------------------------------------------------------
# DANO
# ---------------------------------------------------------

func dano_continuo() -> void:
	# Dano imediato e depois a cada "intervalo_dano" (Timer reaproveitado)
	_tick_dano()
	if causando_dano and estado == Estado.PRESO:
		_timer_dano.start()


func _tick_dano() -> void:
	if not causando_dano or estado != Estado.PRESO or not is_instance_valid(Cortador):
		_timer_dano.stop()
		return

	Cortador.tomar_dano(dano)


# ---------------------------------------------------------
# QUEDA DO CORTADOR (arremesso + gravidade até o chão)
# ---------------------------------------------------------

func _quando_driftar(direcao_drift: Vector3) -> void:
	if estado != Estado.PRESO:
		return

	causando_dano = false
	cair_do_cortador(direcao_drift)


func cair_do_cortador(direcao_drift: Vector3) -> void:
	if estado != Estado.PRESO:
		return

	estado = Estado.ARREMESSADO
	causando_dano = false
	_timer_dano.stop()

	var posicao_atual := global_position

	# Sai do Marker sem mudar de posição visual
	reparent(pai_original, true)
	global_position = posicao_atual

	colisao.set_deferred("disabled", false)

	# Joga para o lado
	var lado := Vector3(-direcao_drift.z, 0.0, direcao_drift.x)

	if lado.length_squared() > 0.0001:
		lado = lado.normalized()
	else:
		lado = Vector3.RIGHT

	# Impulso inicial: sobe até "altura_arremesso" e depois a gravidade faz o resto.
	# A velocidade horizontal é calculada para percorrer ~"distancia_arremesso" no tempo do arco.
	var g := maxf(get_gravity().length(), 0.01)
	var v0 := sqrt(2.0 * g * altura_arremesso)
	var tempo_voo := maxf(2.0 * v0 / g, 0.05)

	velocity = lado * (distancia_arremesso / tempo_voo) + Vector3.UP * v0
	_tempo_arremesso = 0.0
	set_physics_process(true)


func _atualizar_arremesso(delta: float) -> void:
	_tempo_arremesso += delta

	# Gravidade real: cai até o move_and_slide detectar o chão
	velocity += get_gravity() * delta

	# Gira enquanto é arremessado
	rotation.x += velocidade_giro_arremesso * delta

	move_and_slide()

	# Tocou o chão (ignora os primeiros instantes, em que ainda está subindo)
	if _tempo_arremesso > 0.1 and is_on_floor():
		ficar_caido()


func ficar_caido() -> void:
	if not is_inside_tree():
		return

	estado = Estado.CAIDO
	velocity = Vector3.ZERO

	# Deitado rente ao chão
	rotation.x = deg_to_rad(90.0)
	rotation.z = 0.0

	# Assenta no chão com a colisão já deitada (evita ficar flutuando ou afundado)
	move_and_collide(Vector3.DOWN * 0.2)

	# Caído não precisa de física
	set_physics_process(false)

	# Só pode ser atropelado neste estado
	if not is_in_group(GRUPO_ATROPELAVEL):
		add_to_group(GRUPO_ATROPELAVEL)

	_timer_caido.start()


func _acabou_tempo_caido() -> void:
	if is_inside_tree() and estado == Estado.CAIDO:
		levantar()


func levantar() -> void:
	if estado != Estado.CAIDO:
		return

	if is_in_group(GRUPO_ATROPELAVEL):
		remove_from_group(GRUPO_ATROPELAVEL)

	rotation.x = 0.0
	rotation.z = 0.0

	estado = Estado.PERSEGUINDO
	set_physics_process(true)


func morrer_atropelado() -> void:
	if estado != Estado.CAIDO:
		return

	causando_dano = false
	queue_free()
