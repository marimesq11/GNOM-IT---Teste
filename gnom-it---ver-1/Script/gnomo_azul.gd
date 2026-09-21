extends CharacterBody3D

# MOVIMENTO
@export var velocidade: float = 1.3
@export var distancia_pulo: float = 1.0
@export var tempo_pulo: float = 0.5
@export var altura_pulo: float = 1.0

# DANO
@export var dano: float = 2.0
@export var intervalo_dano: float = 1

# QUEDA
@export var distancia_arremesso: float = 2
@export var altura_arremesso: float = 0.6
@export var duracao_arremesso: float = 0.45
@export var tempo_caido: float = 4.0

# REFERÊNCIAS
@onready var Cortador: CharacterBody3D = %cortador
@export var ponto_destino: Marker3D
@onready var colisao: CollisionShape3D = $CollisionShape3D

enum Estado {PERSEGUINDO, PULANDO, PRESO, CAIDO}
var estado = Estado.PERSEGUINDO

var causando_dano: bool = false
var pai_original: Node


func _ready():
	pai_original = get_parent()

	if is_instance_valid(Cortador):
		Cortador.driftou.connect(_quando_driftar)


func _physics_process(_delta):
	if estado != Estado.PERSEGUINDO:
		return

	if not is_instance_valid(Cortador) or not is_instance_valid(ponto_destino):
		return

	var diferenca := Cortador.global_position - global_position
	diferenca.y = 0.0

	var distancia_quadrada := diferenca.length_squared()

	if distancia_quadrada <= distancia_pulo * distancia_pulo:
		comecar_pulo()
		return

	if distancia_quadrada <= 0.0001:
		velocity = Vector3.ZERO
		return

	var direcao := diferenca.normalized()

	velocity.x = direcao.x * velocidade
	velocity.z = direcao.z * velocidade
	velocity.y = 0.0

	move_and_slide()

	rotation.y = atan2(direcao.x, direcao.z) + PI / 2


func comecar_pulo():
	if estado != Estado.PERSEGUINDO:
		return

	estado = Estado.PULANDO
	velocity = Vector3.ZERO
	pular_para_cortador()


func pular_para_cortador():
	var inicio := global_position
	var tempo := 0.0

	while tempo < tempo_pulo:
		if not is_instance_valid(Cortador) or not is_instance_valid(ponto_destino):
			return

		var delta := get_process_delta_time()
		tempo += delta

		var progresso := clampf(tempo / tempo_pulo, 0.0, 1.0)
		var destino := ponto_destino.global_position
		var nova_posicao := inicio.lerp(destino, progresso)

		nova_posicao.y += sin(progresso * PI) * altura_pulo
		global_position = nova_posicao

		await get_tree().process_frame

	ficar_no_cortador()


func ficar_no_cortador():
	if estado != Estado.PULANDO:
		return

	estado = Estado.PRESO
	velocity = Vector3.ZERO

	colisao.set_deferred("disabled", true)

	# Fica preso ao Marker do cortador
	reparent(ponto_destino, true)
	position = Vector3.ZERO

	# Não precisa calcular perseguição enquanto está preso
	set_physics_process(false)

	causando_dano = true
	dano_continuo()


func dano_continuo():
	while causando_dano and estado == Estado.PRESO:
		if not is_instance_valid(Cortador):
			return

		Cortador.tomar_dano(dano)

		await get_tree().create_timer(intervalo_dano).timeout


func _quando_driftar(direcao_drift: Vector3):
	if estado != Estado.PRESO:
		return

	causando_dano = false
	cair_do_cortador(direcao_drift)


func cair_do_cortador(direcao_drift: Vector3):
	if estado != Estado.PRESO:
		return

	estado = Estado.PULANDO
	causando_dano = false

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

	var inicio := global_position
	var destino := inicio + lado * distancia_arremesso
	var tempo := 0.0

	while tempo < duracao_arremesso:
		var delta := get_process_delta_time()
		tempo += delta

		var progresso := clampf(tempo / duracao_arremesso, 0.0, 1.0)
		var nova_posicao := inicio.lerp(destino, progresso)

		nova_posicao.y += sin(progresso * PI) * altura_arremesso
		global_position = nova_posicao

		# Gira enquanto é arremessado
		rotation.x += 8.0 * delta

		await get_tree().process_frame

	ficar_caido()


func ficar_caido():
	if not is_inside_tree():
		return

	estado = Estado.CAIDO
	velocity = Vector3.ZERO

	# Deitado rente ao chão
	rotation.x = deg_to_rad(90.0)
	rotation.z = 0.0

	# Só pode ser atropelado neste estado
	if not is_in_group("atropelavel"):
		add_to_group("atropelavel")

	await get_tree().create_timer(tempo_caido).timeout

	if not is_inside_tree():
		return

	if estado == Estado.CAIDO:
		levantar()


func levantar():
	if estado != Estado.CAIDO:
		return

	if is_in_group("atropelavel"):
		remove_from_group("atropelavel")

	rotation.x = 0.0
	rotation.z = 0.0

	estado = Estado.PERSEGUINDO
	set_physics_process(true)


func morrer_atropelado():
	if estado != Estado.CAIDO:
		return

	causando_dano = false
	queue_free()
