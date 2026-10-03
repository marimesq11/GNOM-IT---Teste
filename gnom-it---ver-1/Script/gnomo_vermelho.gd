extends CharacterBody3D

# DANO
@export var dano: float = 5
var sendo_atropelado: bool = false

# Var Velocidade
var velocidade = 3.5
var velocidade_rotacao = 2.0
var velocidade_ataque = 3

# Var Cortador
@export var Cortador: CharacterBody3D

# Var Distancia
var distancia_cercar = 0.6
var forca_recuo = 0.6

# Var Tempo
var tempo_parado = 0.5

# Var Estados
var atacando = false
var parado = false

# Posição do inimigo no círculo
var indice_inimigo = 0
var quantidade_inimigos = 1


func _ready():
	atualizar_grupo()


func atualizar_grupo():
	var inimigos = get_tree().get_nodes_in_group("inimigos")

	indice_inimigo = inimigos.find(self)
	quantidade_inimigos = max(inimigos.size(), 1)


func _physics_process(delta):
	if not is_instance_valid(Cortador):
		return

	if parado:
		return

	# Distância horizontal até o cortador
	var diferenca_cortador = Cortador.global_position - global_position
	diferenca_cortador.y = 0.0

	var distancia_quadrada = diferenca_cortador.length_squared()

	# Começa o ataque
	if distancia_quadrada <= distancia_cercar * distancia_cercar:
		atacando = true

	var destino: Vector3

	if atacando:
		destino = Cortador.global_position
	else:
		var angulo = (TAU / quantidade_inimigos) * indice_inimigo
		var offset = Vector3(cos(angulo), 0.0, sin(angulo)) * distancia_cercar
		destino = Cortador.global_position + offset

	# Direção
	var direcao = destino - global_position
	direcao.y = 0.0

	var comprimento_quadrado = direcao.length_squared()

	if comprimento_quadrado > 0.0001:
		direcao /= sqrt(comprimento_quadrado)

		var velocidade_atual = velocidade_ataque if atacando else velocidade

		velocity.x = direcao.x * velocidade_atual
		velocity.z = direcao.z * velocidade_atual
		velocity.y = 0.0

		move_and_slide()

		# Rotação
		var angulo_desejado = atan2(direcao.x, direcao.z)
		rotation.y = lerp_angle(
			rotation.y,
			angulo_desejado + PI / 2,
			velocidade_rotacao * delta
		)

	else:
		velocity = Vector3.ZERO


	# Só verifica colisão se estiver atacando
	if atacando:
		for i in get_slide_collision_count():
			var colisao = get_slide_collision(i)

			if colisao.get_collider() == Cortador:
				ataque_acertou()
				break


func ataque_acertou():
	if sendo_atropelado:
		return

	atacando = false
	parado = true

	Cortador.tomar_dano(dano)

	var direcao_recuo = global_position - Cortador.global_position
	direcao_recuo.y = 0.0

	if direcao_recuo.length_squared() > 0.0001:
		direcao_recuo = direcao_recuo.normalized()
		global_position += direcao_recuo * forca_recuo

	velocity = Vector3.ZERO

	await get_tree().create_timer(tempo_parado).timeout

	if is_inside_tree():
		parado = false
	
func morrer_atropelado():
	if sendo_atropelado:
		return

	sendo_atropelado = true
	atacando = false
	parado = true
	velocity = Vector3.ZERO

	# Para qualquer lógica do inimigo imediatamente
	set_physics_process(false)
	set_process(false)

	# Some imediatamente
	hide()

	# Desliga colisões
	collision_layer = 0
	collision_mask = 0

	queue_free()
