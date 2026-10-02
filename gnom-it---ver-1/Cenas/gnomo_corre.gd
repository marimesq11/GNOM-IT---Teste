extends CharacterBody3D

@export var velocidade_fuga: float = 2.7
@export var distancia_deteccao: float = 30
@export var distancia_parede: float = 4
@export var aceleracao: float = 12.0

var player: Node3D = null
var esta_morto: bool = false
var direcao_fuga := Vector3.ZERO

func _ready():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

	if player:
		print("PLAYER ENCONTRADO: ", player.name)
	else:
		print("ERRO: PLAYER NÃO ENCONTRADO!")

func _physics_process(delta: float) -> void:
	if esta_morto or player == null:
		return

	var distancia = global_position.distance_to(player.global_position)

	if distancia <= distancia_deteccao:
		var direcao_player = player.global_position.direction_to(global_position)
		direcao_player.y = 0.0
		direcao_player = direcao_player.normalized()

		var espaco = verificar_parede(direcao_player)

		if espaco:
			direcao_fuga = direcao_player
		else:
			var esquerda = Vector3(-direcao_player.z, 0, direcao_player.x)
			var direita = Vector3(direcao_player.z, 0, -direcao_player.x)

			if pode_andar(esquerda):
				direcao_fuga = esquerda
			elif pode_andar(direita):
				direcao_fuga = direita
			else:
				direcao_fuga = direcao_player

	else:
		direcao_fuga = Vector3.ZERO

	var velocidade_desejada = direcao_fuga * velocidade_fuga

	velocity.x = move_toward(velocity.x, velocidade_desejada.x, aceleracao * delta)
	velocity.z = move_toward(velocity.z, velocidade_desejada.z, aceleracao * delta)

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	if direcao_fuga.length() > 0.1:
		var target_rotation = atan2(direcao_fuga.x, direcao_fuga.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 10.0 * delta)

func verificar_parede(direcao: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state

	var origem = global_position
	var destino = origem + direcao * distancia_parede

	var query = PhysicsRayQueryParameters3D.create(origem, destino)
	query.exclude = [self]

	var resultado = space_state.intersect_ray(query)

	return resultado.is_empty()

func pode_andar(direcao: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state

	var origem = global_position
	var destino = origem + direcao.normalized() * distancia_parede

	var query = PhysicsRayQueryParameters3D.create(origem, destino)
	query.exclude = [self]

	var resultado = space_state.intersect_ray(query)

	return resultado.is_empty()

func morrer_atropelado():
	GameManager.adicionar_pontos(10, global_position)
	if esta_morto:
		return

	esta_morto = true
	print("Gnomo foi atropelado e esmagado pelo dash!")

	$CollisionShape3D.set_deferred("disabled", true)
	queue_free()
