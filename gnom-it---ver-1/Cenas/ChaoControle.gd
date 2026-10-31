
extends StaticBody3D

# ==========================================
# REFERÊNCIAS
# ==========================================

@export var cortador: Node3D
@export var chao_mesh: MeshInstance3D


# ==========================================
# CONFIGURAÇÕES
# ==========================================

@export var tamanho_terreno: Vector2 = Vector2(23.0, 23.0)

# Raio real do corte em unidades do mundo 3D
@export var raio_corte: float = 0.5

# Distância mínima para atualizar
@export var distancia_minima: float = 0.02

const RESOLUCAO: int = 512


# ==========================================
# VARIÁVEIS
# ==========================================

var mascara: Image
var textura_mascara: ImageTexture
var material_chao: ShaderMaterial

var ultima_posicao: Vector3
var primeiro_corte: bool = true

var centro_terreno: Vector2


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:

	if cortador == null or chao_mesh == null:
		push_error("Configure Cortador e ChaoMesh no Inspector!")
		set_process(false)
		return

	material_chao = chao_mesh.get_active_material(0) as ShaderMaterial

	if material_chao == null:
		push_error("ShaderMaterial não encontrado no ChaoMesh!")
		set_process(false)
		return

	# Centro real do terreno no mundo
	centro_terreno = Vector2(
		chao_mesh.global_position.x,
		chao_mesh.global_position.z
	)

	# Cria a máscara branca
	mascara = Image.create(
		RESOLUCAO,
		RESOLUCAO,
		false,
		Image.FORMAT_RGBA8
	)

	mascara.fill(Color.WHITE)

	textura_mascara = ImageTexture.create_from_image(mascara)

	# Envia as configurações ao shader
	material_chao.set_shader_parameter("mascara", textura_mascara)
	material_chao.set_shader_parameter("tamanho_terreno", tamanho_terreno)
	material_chao.set_shader_parameter("centro_terreno", centro_terreno)

	ultima_posicao = cortador.global_position

	print("CONTROLE DO CHÃO INICIADO!")


# ==========================================
# ATUALIZAÇÃO
# ==========================================

func _process(_delta: float) -> void:

	if not is_instance_valid(cortador):
		return

	var posicao_atual = cortador.global_position

	# Ignora movimento vertical
	var atual_2d = Vector2(posicao_atual.x, posicao_atual.z)
	var anterior_2d = Vector2(ultima_posicao.x, ultima_posicao.z)

	var distancia = atual_2d.distance_to(anterior_2d)

	if not primeiro_corte and distancia < distancia_minima:
		return

	# Pinta pontos intermediários para não deixar buracos
	var passos = max(
		1,
		int(ceil(distancia / max(raio_corte * 0.5, 0.01)))
	)

	var alterou = false

	for i in range(passos + 1):

		var t = float(i) / float(passos)
		var posicao = anterior_2d.lerp(atual_2d, t)

		if pintar_circulo(posicao):
			alterou = true

	# Atualiza a máscara somente quando houver alterações
	if alterou:
		textura_mascara.update(mascara)

	ultima_posicao = posicao_atual
	primeiro_corte = false


# ==========================================
# PINTAR CÍRCULO AO REDOR DO CORTADOR
# ==========================================

func pintar_circulo(posicao: Vector2) -> bool:

	# Posição do cortador em relação ao centro do terreno
	var relativa = posicao - centro_terreno

	# Converte posição mundial para coordenadas da máscara
	var uv = Vector2(
		relativa.x / tamanho_terreno.x + 0.5,
		relativa.y / tamanho_terreno.y + 0.5
	)

	# Converte UV para pixels
	var centro_x = int(uv.x * RESOLUCAO)
	var centro_y = int(uv.y * RESOLUCAO)

	# Raio circular convertido para pixels
	var raio_x = max(
		1,
		int(raio_corte / tamanho_terreno.x * RESOLUCAO)
	)

	var raio_y = max(
		1,
		int(raio_corte / tamanho_terreno.y * RESOLUCAO)
	)

	var alterou = false

	# Percorre apenas a região próxima ao cortador
	for y in range(
		max(0, centro_y - raio_y),
		min(RESOLUCAO, centro_y + raio_y + 1)
	):
		for x in range(
			max(0, centro_x - raio_x),
			min(RESOLUCAO, centro_x + raio_x + 1)
		):

			# Distância normalizada até o centro do círculo
			var dx = float(x - centro_x) / float(raio_x)
			var dy = float(y - centro_y) / float(raio_y)

			if dx * dx + dy * dy <= 1.0:

				if mascara.get_pixel(x, y).r > 0.0:
					mascara.set_pixel(x, y, Color.BLACK)
					alterou = true

	return alterou
