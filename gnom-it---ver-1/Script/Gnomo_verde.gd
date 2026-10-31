
extends CharacterBody3D

# =========================================================
# SISTEMA DE GRAMA
# =========================================================

@export var sistema_grama: SistemaGrama
@export var sistema_chao: StaticBody3D

var sendo_atropelado: bool = false

# =========================================================
# MOVIMENTO
# =========================================================

@export var velocidade: float = 3.5
@export var distancia_chegada: float = 0.2

# =========================================================
# RESTAURAÇÃO
# =========================================================

@export var raio_restauracao: float = 1.5
@export var velocidade_restauracao: float = 0.5
@export var intervalo_restauracao: float = 0.05

@export var distancia_entre_gnomos: float = 3.0

# =========================================================
# PARTÍCULA DE MAGIA
# =========================================================

@export var gnomo_verde_magia: GPUParticles3D

# =========================================================
# PROCURA
# =========================================================

@export var passo_busca: int = 32
@export var intervalo_busca: float = 0.3

# =========================================================
# SONS ALEATÓRIOS
# =========================================================

@export var intervalo_som_min: float = 1.0
@export var intervalo_som_max: float = 3.0
@export var pitch_som_min: float = 0.8
@export var pitch_som_max: float = 1.4

var _timer_som: Timer

# =========================================================
# VARIÁVEIS
# =========================================================

var possui_alvo: bool = false
var alvo_mundo: Vector3 = Vector3.ZERO
var alvo_pixel: Vector2i = Vector2i.ZERO

var tempo_busca: float = 0.0
var tempo_restauracao: float = 0.0

# =========================================================
# INICIALIZAÇÃO
# =========================================================

func _ready() -> void:
	add_to_group("gnomos_restauradores")

	_timer_som = Timer.new()
	_timer_som.one_shot = true
	_timer_som.timeout.connect(_tocar_som_andando)
	add_child(_timer_som)

	tempo_busca = randf_range(0.0, intervalo_busca)

	_desativar_magia()

# =========================================================
# PARTÍCULA DE MAGIA
# =========================================================

func _ativar_magia() -> void:
	if gnomo_verde_magia == null:
		return

	if not gnomo_verde_magia.emitting:
		gnomo_verde_magia.emitting = true


func _desativar_magia() -> void:
	if gnomo_verde_magia == null:
		return

	if gnomo_verde_magia.emitting:
		gnomo_verde_magia.emitting = false

# =========================================================
# SONS
# =========================================================

func _agendar_som_andando() -> void:
	if sendo_atropelado:
		return

	var intervalo = randf_range(
		intervalo_som_min,
		intervalo_som_max
	)

	_timer_som.start(maxf(intervalo, 0.01))


func _tocar_som_andando() -> void:
	if sendo_atropelado or not possui_alvo:
		return

	if Vector2(velocity.x, velocity.z).length_squared() < 0.01:
		return

	# $GnomoSons.pitch_scale = randf_range(
	#     pitch_som_min, pitch_som_max
	# )
	# $GnomoSons.play()
	# _agendar_som_andando()

# =========================================================
# PROCESSO PRINCIPAL
# =========================================================

func _physics_process(delta: float) -> void:
	if sendo_atropelado:
		_desativar_magia()
		return

	if not is_instance_valid(sistema_grama):
		_desativar_magia()
		return

	if sistema_grama.mascara == null:
		_desativar_magia()
		return

	if not possui_alvo:
		_desativar_magia()

		velocity.x = 0.0
		velocity.z = 0.0

		# ANIMAÇÃO: PARAR
		# $AnimationPlayer.stop()

		_timer_som.stop()

		tempo_busca += delta

		if tempo_busca >= intervalo_busca:
			tempo_busca = 0.0
			procurar_grama_cortada()

	if possui_alvo:
		var dx = alvo_mundo.x - global_position.x
		var dz = alvo_mundo.z - global_position.z

		var distancia_quadrada = dx * dx + dz * dz

		if distancia_quadrada > distancia_chegada * distancia_chegada:
			_desativar_magia()
			mover_para_alvo(dx, dz)

			# ANIMAÇÃO: GnomoAndando
			# $AnimationPlayer.play("GnomoAndando")

			# AUDIO: GnomoSons
			# if _timer_som.is_stopped():
			#     _agendar_som_andando()

		else:
			velocity.x = 0.0
			velocity.z = 0.0

			# ANIMAÇÃO: GnomoRestaurando
			# $AnimationPlayer.play("GnomoRestaurando")

			_timer_som.stop()

			_ativar_magia()

			tempo_restauracao += delta

			if tempo_restauracao >= intervalo_restauracao:
				var tempo_passado = tempo_restauracao
				tempo_restauracao = 0.0
				restaurar_grama(tempo_passado)

				if not possui_alvo:
					_desativar_magia()

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

# =========================================================
# VERIFICAR SE REGIÃO ESTÁ RESERVADA
# =========================================================

func regiao_ocupada(posicao: Vector3) -> bool:
	for gnomo in get_tree().get_nodes_in_group("gnomos_restauradores"):
		if gnomo == self:
			continue

		if not is_instance_valid(gnomo):
			continue

		if gnomo.sendo_atropelado:
			continue

		if not gnomo.possui_alvo:
			continue

		if gnomo.sistema_grama != sistema_grama:
			continue

		var distancia = Vector2(
			posicao.x - gnomo.alvo_mundo.x,
			posicao.z - gnomo.alvo_mundo.z
		).length()

		if distancia < distancia_entre_gnomos:
			return true

	return false

# =========================================================
# PROCURAR GRAMA CORTADA
# =========================================================

func procurar_grama_cortada() -> void:
	var mascara: Image = sistema_grama.mascara
	var tamanho_mascara: int = sistema_grama.TAMANHO_MASCARA

	var melhor_distancia_quadrada = INF
	var melhor_pixel = Vector2i.ZERO
	var encontrou = false

	for y in range(0, tamanho_mascara, maxi(passo_busca, 1)):
		for x in range(0, tamanho_mascara, maxi(passo_busca, 1)):
			var valor = mascara.get_pixel(x, y).r

			if valor >= 0.95:
				continue

			var posicao_mundo = sistema_grama.mascara_para_mundo(
				Vector2(x, y)
			)

			if regiao_ocupada(posicao_mundo):
				continue

			var dx = posicao_mundo.x - global_position.x
			var dz = posicao_mundo.z - global_position.z

			var distancia_quadrada = dx * dx + dz * dz

			if distancia_quadrada < melhor_distancia_quadrada:
				melhor_distancia_quadrada = distancia_quadrada
				melhor_pixel = Vector2i(x, y)
				encontrou = true

	if encontrou:
		alvo_pixel = melhor_pixel

		alvo_mundo = sistema_grama.mascara_para_mundo(
			Vector2(melhor_pixel.x, melhor_pixel.y)
		)

		possui_alvo = true
	else:
		possui_alvo = false
		_desativar_magia()

# =========================================================
# MOVIMENTO
# =========================================================

func mover_para_alvo(dx: float, dz: float) -> void:
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

	look_at(
		Vector3(alvo_mundo.x, global_position.y, alvo_mundo.z),
		Vector3.UP
	)

# =========================================================
# RESTAURAR GRAMA
# =========================================================

func restaurar_grama(tempo_passado: float) -> void:
	var mascara: Image = sistema_grama.mascara
	var tamanho_mascara: int = sistema_grama.TAMANHO_MASCARA
	var tamanho_terreno: Vector2 = sistema_grama.tamanho_terreno

	var posicao_mascara = sistema_grama.mundo_para_mascara(
		global_position
	)

	var pixels_por_metro_x = float(tamanho_mascara) / tamanho_terreno.x
	var pixels_por_metro_y = float(tamanho_mascara) / tamanho_terreno.y

	var raio_pixels_x = raio_restauracao * pixels_por_metro_x
	var raio_pixels_y = raio_restauracao * pixels_por_metro_y

	if raio_pixels_x <= 0.0 or raio_pixels_y <= 0.0:
		_desativar_magia()
		return

	var centro_x = int(posicao_mascara.x)
	var centro_y = int(posicao_mascara.y)

	var inicio_x = max(centro_x - int(ceil(raio_pixels_x)), 0)
	var fim_x = min(centro_x + int(ceil(raio_pixels_x)), tamanho_mascara - 1)
	var inicio_y = max(centro_y - int(ceil(raio_pixels_y)), 0)
	var fim_y = min(centro_y + int(ceil(raio_pixels_y)), tamanho_mascara - 1)

	var crescimento = velocidade_restauracao * tempo_passado
	var alterou_mascara = false

	for y in range(inicio_y, fim_y + 1):
		var distancia_y = (
			float(y) - posicao_mascara.y
		) / raio_pixels_y

		var distancia_y_quadrada = distancia_y * distancia_y

		for x in range(inicio_x, fim_x + 1):
			var distancia_x = (
				float(x) - posicao_mascara.x
			) / raio_pixels_x

			if distancia_x * distancia_x + distancia_y_quadrada <= 1.0:
				var valor_atual = mascara.get_pixel(x, y).r

				if valor_atual < 1.0:
					var novo_valor = minf(
						valor_atual + crescimento,
						1.0
					)

					mascara.set_pixel(
						x, y,
						Color(novo_valor, novo_valor, novo_valor, 1.0)
					)

					alterou_mascara = true

	if alterou_mascara:
		sistema_grama.textura_mascara.update(mascara)
		sistema_grama.atualizar_pixels_cortados()

	# Restaura também a textura do chão
	restaurar_textura_chao(tempo_passado)

	# Verifica se terminou de restaurar a região
	var valor_alvo = mascara.get_pixel(
		alvo_pixel.x,
		alvo_pixel.y
	).r

	if valor_alvo >= 0.95:
		possui_alvo = false
		velocity.x = 0.0
		velocity.z = 0.0
		tempo_restauracao = 0.0
		tempo_busca = intervalo_busca

		_desativar_magia()

# =========================================================
# RESTAURAR TEXTURA DO CHÃO
# =========================================================

func restaurar_textura_chao(tempo_passado: float) -> void:
	if not is_instance_valid(sistema_chao):
		return

	var mascara_chao: Image = sistema_chao.mascara
	var textura_chao: ImageTexture = sistema_chao.textura_mascara

	if mascara_chao == null or textura_chao == null:
		return

	var tamanho: Vector2 = sistema_chao.tamanho_terreno
	var centro: Vector2 = sistema_chao.centro_terreno

	if tamanho.x <= 0.0 or tamanho.y <= 0.0:
		return

	var largura = mascara_chao.get_width()
	var altura = mascara_chao.get_height()

	var uv = Vector2(
		(global_position.x - centro.x) / tamanho.x + 0.5,
		(global_position.z - centro.y) / tamanho.y + 0.5
	)

	var posicao_pixel = Vector2(
		uv.x * largura,
		uv.y * altura
	)

	var raio_x = raio_restauracao / tamanho.x * largura
	var raio_y = raio_restauracao / tamanho.y * altura

	if raio_x <= 0.0 or raio_y <= 0.0:
		return

	var inicio_x = maxi(0, int(floor(posicao_pixel.x - raio_x)))
	var fim_x = mini(largura - 1, int(ceil(posicao_pixel.x + raio_x)))
	var inicio_y = maxi(0, int(floor(posicao_pixel.y - raio_y)))
	var fim_y = mini(altura - 1, int(ceil(posicao_pixel.y + raio_y)))

	var crescimento = velocidade_restauracao * tempo_passado
	var alterou = false

	for y in range(inicio_y, fim_y + 1):
		var dy = (float(y) - posicao_pixel.y) / raio_y

		for x in range(inicio_x, fim_x + 1):
			var dx = (float(x) - posicao_pixel.x) / raio_x

			if dx * dx + dy * dy <= 1.0:
				var valor_atual = mascara_chao.get_pixel(x, y).r

				if valor_atual < 1.0:
					var novo_valor = minf(
						valor_atual + crescimento,
						1.0
					)

					mascara_chao.set_pixel(
						x, y,
						Color(novo_valor, novo_valor, novo_valor, 1.0)
					)

					alterou = true

	if alterou:
		textura_chao.update(mascara_chao)

# =========================================================
# MORTE POR ATROPELAMENTO
# =========================================================

func morrer_atropelado() -> void:
	if sendo_atropelado:
		return

	GameManager.adicionar_pontos(50, global_position)
	GameManager.registrar_gnomo()

	sendo_atropelado = true
	possui_alvo = false
	velocity = Vector3.ZERO

	_desativar_magia()

	_timer_som.stop()

	# ANIMAÇÃO: PARAR
	# $AnimationPlayer.stop()

	# AUDIO: GnomoMorte
	# $GnomoMorte.play()

	# PARTÍCULA: GnomoMorte
	# $ParticulaGnomoMorte.emitting = true

	$AudioStreamPlayer/Morreu.play()

	set_physics_process(false)
	set_process(false)

	hide()

	collision_layer = 0
	collision_mask = 0

	await get_tree().create_timer(1.0).timeout
	queue_free()
