extends MeshInstance3D


# =========================================================
# REFERÊNCIAS
# =========================================================

@onready var cortador = $"../../cortador/Node3D"
@export var grama: MeshInstance3D


# =========================================================
# TERRENO
# =========================================================

@export var tamanho_terreno: Vector2 = Vector2(20.0, 20.0)

var centro_terreno: Vector2


# =========================================================
# CORTE
# =========================================================

@export var raio_corte: float = 0.25
@export var distancia_atras: float = 0.1

# Quantas vezes por segundo o rastro pode ser atualizado.
# 0.033 = aproximadamente 30 vezes por segundo.
@export var intervalo_corte: float = 0.033

# Distância mínima que o cortador precisa andar
# antes de tentarmos pintar novamente.
@export var distancia_minima_corte: float = 0.03

var tempo_corte: float = 0.0
var ultima_posicao_corte: Vector3
var primeira_atualizacao: bool = true


# =========================================================
# MÁSCARA
# =========================================================

const TAMANHO_MASCARA: int = 512
const TOTAL_PIXELS: int = TAMANHO_MASCARA * TAMANHO_MASCARA

var mascara: Image
var textura_mascara: ImageTexture

var material_chao: ShaderMaterial
var material_grama: ShaderMaterial


# Valores calculados uma única vez.
var pixels_por_metro_x: float
var pixels_por_metro_y: float

var raio_pixels_x: float
var raio_pixels_y: float


# =========================================================
# VITÓRIA
# =========================================================

var pixels_cortados: int = 0
var venceu: bool = false


# =========================================================
# MUNDO -> MÁSCARA
# =========================================================

func mundo_para_mascara(posicao: Vector3) -> Vector2:
	var inicio_x = centro_terreno.x - tamanho_terreno.x * 0.5
	var inicio_z = centro_terreno.y - tamanho_terreno.y * 0.5

	var porcentagem_x = (posicao.x - inicio_x) / tamanho_terreno.x
	var porcentagem_z = (posicao.z - inicio_z) / tamanho_terreno.y

	return Vector2(
		porcentagem_x * TAMANHO_MASCARA,
		porcentagem_z * TAMANHO_MASCARA
	)


# =========================================================
# MÁSCARA -> MUNDO
# =========================================================

func mascara_para_mundo(posicao_mascara: Vector2) -> Vector3:
	var porcentagem_x = posicao_mascara.x / TAMANHO_MASCARA
	var porcentagem_z = posicao_mascara.y / TAMANHO_MASCARA

	var inicio_x = centro_terreno.x - tamanho_terreno.x * 0.5
	var inicio_z = centro_terreno.y - tamanho_terreno.y * 0.5

	var mundo_x = inicio_x + porcentagem_x * tamanho_terreno.x
	var mundo_z = inicio_z + porcentagem_z * tamanho_terreno.y

	return Vector3(mundo_x, global_position.y, mundo_z)


# =========================================================
# PINTAR GRAMA
# =========================================================

# Retorna true SOMENTE se algum pixel mudou.
func pintar(posicao: Vector2) -> bool:
	var centro_x = int(posicao.x)
	var centro_y = int(posicao.y)

	var inicio_x = max(centro_x - int(ceil(raio_pixels_x)), 0)
	var fim_x = min(centro_x + int(ceil(raio_pixels_x)), TAMANHO_MASCARA - 1)
	var inicio_y = max(centro_y - int(ceil(raio_pixels_y)), 0)
	var fim_y = min(centro_y + int(ceil(raio_pixels_y)), TAMANHO_MASCARA - 1)

	var alterou = false

	# Pré-calculamos os inversos para evitar divisão
	# dentro dos loops.
	var inverso_raio_x = 1.0 / raio_pixels_x
	var inverso_raio_y = 1.0 / raio_pixels_y

	for y in range(inicio_y, fim_y + 1):
		var distancia_y = (float(y) - posicao.y) * inverso_raio_y
		var distancia_y_quadrada = distancia_y * distancia_y

		for x in range(inicio_x, fim_x + 1):
			var distancia_x = (float(x) - posicao.x) * inverso_raio_x

			# Não usa distance_to() nem sqrt().
			if distancia_x * distancia_x + distancia_y_quadrada <= 1.0:
				if mascara.get_pixel(x, y).r > 0.0:
					mascara.set_pixel(x, y, Color.BLACK)
					pixels_cortados += 1
					alterou = true

	return alterou


# =========================================================
# VITÓRIA
# =========================================================

func verificar_vitoria():
	if venceu:
		return

	if float(pixels_cortados) / TOTAL_PIXELS >= 0.94:
		venceu = true
		print("VITÓRIA! 95% da grama foi cortada!")


# =========================================================
# READY
# =========================================================

func _ready():
	centro_terreno = Vector2(global_position.x, global_position.z)

	# Calcula uma vez e reutiliza durante a fase.
	pixels_por_metro_x = float(TAMANHO_MASCARA) / tamanho_terreno.x
	pixels_por_metro_y = float(TAMANHO_MASCARA) / tamanho_terreno.y

	raio_pixels_x = raio_corte * pixels_por_metro_x
	raio_pixels_y = raio_corte * pixels_por_metro_y

	mascara = Image.create(
		TAMANHO_MASCARA,
		TAMANHO_MASCARA,
		false,
		Image.FORMAT_RGBA8
	)

	mascara.fill(Color.WHITE)
	textura_mascara = ImageTexture.create_from_image(mascara)


	# MATERIAL DO CHÃO

	material_chao = get_active_material(0) as ShaderMaterial

	if material_chao == null:
		push_error("O material do chão não é ShaderMaterial!")
	else:
		material_chao.set_shader_parameter("mascara", textura_mascara)
		material_chao.set_shader_parameter("tamanho_terreno", tamanho_terreno)
		material_chao.set_shader_parameter("centro_terreno", centro_terreno)


	# MATERIAL DA GRAMA

	if grama == null:
		push_error("Arraste a grama para o campo Grama!")
		return

	material_grama = grama.get_active_material(0) as ShaderMaterial

	if material_grama == null:
		push_error("O material da grama não é ShaderMaterial!")
		return

	material_grama.set_shader_parameter("mascara", textura_mascara)
	material_grama.set_shader_parameter("tamanho_terreno", tamanho_terreno)
	material_grama.set_shader_parameter("centro_terreno", centro_terreno)


# =========================================================
# PROCESS
# =========================================================

func _process(delta):
	if cortador == null:
		return

	# Não precisamos tentar cortar em todo frame.
	tempo_corte += delta

	if tempo_corte < intervalo_corte:
		return

	tempo_corte = 0.0


	# Calcula a posição do corte.
	var direcao_atras = cortador.global_transform.basis.z.normalized()
	var posicao_corte = cortador.global_position + direcao_atras * distancia_atras


	# =====================================================
	# CORTADOR NÃO SE MOVEU
	# =====================================================

	# Se ele estiver parado, não tem motivo para verificar
	# os mesmos pixels repetidamente.
	if not primeira_atualizacao:
		var movimento_x = posicao_corte.x - ultima_posicao_corte.x
		var movimento_z = posicao_corte.z - ultima_posicao_corte.z
		var distancia_quadrada = movimento_x * movimento_x + movimento_z * movimento_z

		if distancia_quadrada < distancia_minima_corte * distancia_minima_corte:
			return

	primeira_atualizacao = false
	ultima_posicao_corte = posicao_corte


	# =====================================================
	# CONVERTE PARA MÁSCARA
	# =====================================================

	var posicao_mascara = mundo_para_mascara(posicao_corte)

	if (
		posicao_mascara.x < 0.0
		or posicao_mascara.x >= TAMANHO_MASCARA
		or posicao_mascara.y < 0.0
		or posicao_mascara.y >= TAMANHO_MASCARA
	):
		return


	# =====================================================
	# PINTA
	# =====================================================

	var alterou = pintar(posicao_mascara)


	# Só manda a Image inteira para a GPU
	# se realmente cortamos alguma grama nova.
	if alterou:
		textura_mascara.update(mascara)
		verificar_vitoria()
