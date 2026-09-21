extends CharacterBody3D


# =========================================================
# SISTEMA DE GRAMA
# =========================================================

# MeshInstance3D que possui o script da máscara/corte.
@export var sistema_grama: MeshInstance3D

var sendo_atropelado: bool = false

# =========================================================
# MOVIMENTO
# =========================================================

@export var velocidade: float = 2.0
@export var distancia_chegada: float = 0.2


# =========================================================
# RESTAURAÇÃO
# =========================================================

# Raio em METROS que o inimigo restaura.
@export var raio_restauracao: float = 0.5

# Velocidade do crescimento.
@export var velocidade_restauracao: float = 0.3

# De quanto em quanto tempo a máscara é restaurada.
# Não precisamos editar a Image 60 vezes por segundo.
@export var intervalo_restauracao: float = 0.05


# =========================================================
# PROCURA
# =========================================================

# Quanto maior, mais leve e menos precisa é a busca.
# 16 é um bom começo.
@export var passo_busca: int = 32

# Tempo entre buscas quando não existe alvo.
@export var intervalo_busca: float = 0.5


# =========================================================
# VARIÁVEIS
# =========================================================

var possui_alvo: bool = false
var alvo_mundo: Vector3 = Vector3.ZERO
var alvo_pixel: Vector2i = Vector2i.ZERO

var tempo_busca: float = 0.0
var tempo_restauracao: float = 0.0


# =========================================================
# PROCESSO PRINCIPAL
# =========================================================

func _physics_process(delta):
	if sendo_atropelado:
		return

	if sistema_grama == null or sistema_grama.mascara == null:
		return
		
	if sistema_grama == null or sistema_grama.mascara == null:
		return

	if not possui_alvo:
		velocity.x = 0.0
		velocity.z = 0.0

		tempo_busca += delta
		if tempo_busca >= intervalo_busca:
			tempo_busca = 0.0
			procurar_grama_cortada()

	if possui_alvo:
		var dx = alvo_mundo.x - global_position.x
		var dz = alvo_mundo.z - global_position.z
		var distancia_quadrada = dx * dx + dz * dz

		if distancia_quadrada > distancia_chegada * distancia_chegada:
			mover_para_alvo(dx, dz)
		else:
			velocity.x = 0.0
			velocity.z = 0.0

			tempo_restauracao += delta
			if tempo_restauracao >= intervalo_restauracao:
				var tempo_passado = tempo_restauracao
				tempo_restauracao = 0.0
				restaurar_grama(tempo_passado)

	move_and_slide()


# =========================================================
# PROCURAR GRAMA CORTADA
# =========================================================

func procurar_grama_cortada():
	var mascara: Image = sistema_grama.mascara
	var tamanho_mascara: int = sistema_grama.TAMANHO_MASCARA

	var melhor_distancia_quadrada = INF
	var melhor_pixel = Vector2i.ZERO
	var encontrou = false

	# Procura pixels cortados pulando conforme passo_busca.
	for y in range(0, tamanho_mascara, passo_busca):
		for x in range(0, tamanho_mascara, passo_busca):
			# Só precisamos do canal vermelho.
			var valor = mascara.get_pixel(x, y).r

			if valor < 0.95:
				var posicao_mundo: Vector3 = sistema_grama.mascara_para_mundo(Vector2(x, y))

				# Distância ao quadrado é mais barata que distance_to().
				var dx = posicao_mundo.x - global_position.x
				var dz = posicao_mundo.z - global_position.z
				var distancia_quadrada = dx * dx + dz * dz

				if distancia_quadrada < melhor_distancia_quadrada:
					melhor_distancia_quadrada = distancia_quadrada
					melhor_pixel = Vector2i(x, y)
					encontrou = true

	if encontrou:
		alvo_pixel = melhor_pixel
		alvo_mundo = sistema_grama.mascara_para_mundo(Vector2(melhor_pixel.x, melhor_pixel.y))
		possui_alvo = true
	else:
		possui_alvo = false


# =========================================================
# MOVIMENTO
# =========================================================

func mover_para_alvo(dx: float, dz: float):
	var comprimento_quadrado = dx * dx + dz * dz

	if comprimento_quadrado <= 0.0001:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var inverso_comprimento = 1.0 / sqrt(comprimento_quadrado)
	var direcao_x = dx * inverso_comprimento
	var direcao_z = dz * inverso_comprimento

	velocity.x = direcao_x * velocidade
	velocity.z = direcao_z * velocidade

	look_at(Vector3(alvo_mundo.x, global_position.y, alvo_mundo.z), Vector3.UP)


# =========================================================
# RESTAURAR GRAMA
# =========================================================

func restaurar_grama(tempo_passado: float):
	var mascara: Image = sistema_grama.mascara
	var tamanho_mascara: int = sistema_grama.TAMANHO_MASCARA
	var tamanho_terreno: Vector2 = sistema_grama.tamanho_terreno

	# Usa a conversão do NOVO sistema.
	var posicao_mascara: Vector2 = sistema_grama.mundo_para_mascara(global_position)

	# X e Z precisam ser calculados separadamente porque
	# agora o terreno pode ser retangular.
	var pixels_por_metro_x = float(tamanho_mascara) / tamanho_terreno.x
	var pixels_por_metro_y = float(tamanho_mascara) / tamanho_terreno.y

	var raio_pixels_x = raio_restauracao * pixels_por_metro_x
	var raio_pixels_y = raio_restauracao * pixels_por_metro_y

	if raio_pixels_x <= 0.0 or raio_pixels_y <= 0.0:
		return

	var centro_x = int(posicao_mascara.x)
	var centro_y = int(posicao_mascara.y)

	var inicio_x = max(centro_x - int(ceil(raio_pixels_x)), 0)
	var fim_x = min(centro_x + int(ceil(raio_pixels_x)), tamanho_mascara - 1)
	var inicio_y = max(centro_y - int(ceil(raio_pixels_y)), 0)
	var fim_y = min(centro_y + int(ceil(raio_pixels_y)), tamanho_mascara - 1)

	# Como não restauramos todo frame, usamos o tempo realmente
	# acumulado para manter a mesma velocidade visual.
	var crescimento = velocidade_restauracao * tempo_passado
	var alterou_mascara = false

	for y in range(inicio_y, fim_y + 1):
		var distancia_y = (float(y) - posicao_mascara.y) / raio_pixels_y
		var distancia_y_quadrada = distancia_y * distancia_y

		for x in range(inicio_x, fim_x + 1):
			var distancia_x = (float(x) - posicao_mascara.x) / raio_pixels_x

			# Teste de círculo sem distance_to() e sem sqrt().
			if distancia_x * distancia_x + distancia_y_quadrada <= 1.0:
				var valor_atual = mascara.get_pixel(x, y).r

				if valor_atual < 1.0:
					var novo_valor = min(valor_atual + crescimento, 1.0)
					mascara.set_pixel(x, y, Color(novo_valor, novo_valor, novo_valor, 1.0))
					alterou_mascara = true

	# ImageTexture.update() é relativamente caro.
	# Só chama se algum pixel realmente mudou.
	if alterou_mascara:
		sistema_grama.textura_mascara.update(mascara)

	# O pixel que originou esse alvo já foi restaurado.
	var valor_alvo = mascara.get_pixel(alvo_pixel.x, alvo_pixel.y).r

	if valor_alvo >= 0.95:
		possui_alvo = false
		velocity.x = 0.0
		velocity.z = 0.0
		tempo_restauracao = 0.0

		# Não fazemos uma busca pesada aqui imediatamente.
		# O próximo alvo será encontrado pelo intervalo_busca.
		tempo_busca = intervalo_busca

func morrer_atropelado():
	if sendo_atropelado:
		return

	sendo_atropelado = true
	possui_alvo = false
	velocity = Vector3.ZERO

	set_physics_process(false)
	set_process(false)

	hide()

	collision_layer = 0
	collision_mask = 0

	queue_free()
