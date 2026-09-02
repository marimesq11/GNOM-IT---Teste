extends MeshInstance3D


# @onready faz essa variável ser preenchida quando o nó estiver pronto.
@onready var cortador = $"../../cortador/Node3D"

# Arraste o nó MeshInstance3D da nova grama
# para este campo no Inspector.
@export var grama: MeshInstance3D

# Materiais utilizados pelo chão e pela grama.
var material_chao: ShaderMaterial
var material_grama: ShaderMaterial

# Tamanho do círculo que corta a grama.
# Esse valor está em unidades do mundo.
@export var raio_corte: float = 0.18

# Distância que o círculo fica atrás do cortador.
@export var distancia_atras: float = 0.1


# MÁSCARA

# Imagem que podemos modificar pelo código.
var mascara: Image

# Versão da Image que pode ser enviada para o shader.
var textura_mascara: ImageTexture

# Tamanho da máscara.
const TAMANHO_MASCARA: int = 512

# Quantidade total de pixels da máscara.
const TOTAL_PIXELS: int = TAMANHO_MASCARA * TAMANHO_MASCARA



# VITÓRIA
var pixels_cortados: int = 0
var venceu: bool = false




# PINTAR O RASTRO
# PINTAR O RASTRO
func pintar(posicao: Vector2):

	# Nosso terreno possui 20 unidades
	# e nossa máscara possui 512 pixels.
	#
	# Então:
	# 512 / 20 = 25.6 pixels por unidade.
	var pixels_por_metro = 512.0 / 20.0


	# Converte o raio do corte
	# de unidades do mundo para pixels.
	var raio_pixels = int(raio_corte * pixels_por_metro)


	# Centro do círculo dentro da máscara.
	var centro_x = int(posicao.x)
	var centro_y = int(posicao.y)


	# Calcula apenas a região próxima do círculo.
	var inicio_x = max(centro_x - raio_pixels, 0)
	var fim_x = min(centro_x + raio_pixels, 511)

	var inicio_y = max(centro_y - raio_pixels, 0)
	var fim_y = min(centro_y + raio_pixels, 511)


	for y in range(inicio_y, fim_y + 1):
		for x in range(inicio_x, fim_x + 1):

			# Calcula a distância entre
			# esse pixel e o centro do círculo.
			var distancia = Vector2(x, y).distance_to(posicao)


			# Se estiver dentro do círculo...
			if distancia <= raio_pixels:

				# Verifica se esse pedaço
				# ainda não tinha sido cortado.
				if mascara.get_pixel(x, y) != Color.BLACK:

					# Pinta de preto.
					mascara.set_pixel(x, y, Color.BLACK)

					# Conta mais um pixel cortado.
					pixels_cortados += 1



func mundo_para_mascara(posicao: Vector3) -> Vector2:
	
	# O cortador possui X, Y e Z porque está no mundo 3D.
	# A máscara é 2D, então possui somente X e Y.
	#
	# No chão usamos:
	#
	# X = esquerda/direita
	# Z = frente/trás
	#
	# Por isso:
	#
	# X do mundo -> X da máscara
	# Z do mundo -> Y da máscara
	
	
	# Nosso terreno possui 20 unidades:
	#
	# -10 -------- 0 -------- +10
	#              ↑
	#            centro
	#
	#
	# +10 transforma:
	#
	# -10 -------- 0 -------- +10
	#
	# em:
	#
	#  0 -------- 10 -------- 20
	#
	#
	# /20 transforma a posição em
	# uma porcentagem entre 0 e 1.
	#
	# *512 transforma essa porcentagem
	# no pixel correspondente da máscara.
	
	var x = (posicao.x + 10.0) / 20.0 * 512.0
	var y = (posicao.z + 10.0) / 20.0 * 512.0
	
	
	# Devolve a posição correspondente na máscara.
	return Vector2(x, y)



# VERIFICAR VITÓRIA
func verificar_vitoria():
	if venceu:
		return
	
	var porcentagem = float(pixels_cortados) / float(TOTAL_PIXELS)
	if porcentagem >= 0.94:
		
		venceu = true
		
		print("VITÓRIA! 95% da grama foi cortada!")


#CRIANDO A MASCARA

func _ready():

	# Cria uma imagem de 512 × 512 pixels.
	mascara = Image.create(
		512,
		512,
		false,
		Image.FORMAT_RGBA8
	)

	# Branco significa grama inteira.
	mascara.fill(Color.WHITE)

	# Transforma a imagem em uma textura.
	textura_mascara = ImageTexture.create_from_image(
		mascara
	)

	# Pega o material ativo do chão.
	material_chao = get_active_material(0) as ShaderMaterial

	if material_chao == null:
		push_error(
			"O material ativo do chão não é um ShaderMaterial!"
		)
	else:
		# Envia a máscara para o shader do chão.
		material_chao.set_shader_parameter(
			"mascara",
			textura_mascara
		)

	# Verifica se a nova grama foi colocada.
	if grama == null:
		push_error(
			"Arraste o MeshInstance3D da grama para o campo Grama!"
		)
		return

	# Pega o material realmente utilizado
	# pela superfície da nova grama.
	material_grama = grama.get_active_material(0) as ShaderMaterial

	if material_grama == null:
		push_error(
			"O material ativo da grama não é um ShaderMaterial!"
		)
		return

	# Envia a mesma máscara para o shader da grama.
	material_grama.set_shader_parameter(
		"mascara",
		textura_mascara
	)

	# Seu terreno possui 20 × 20.
	material_grama.set_shader_parameter(
		"tamanho_terreno",
		20.0
	)

	# O terreno ocupa de -10 até +10.
	material_grama.set_shader_parameter(
		"centro_terreno",
		Vector2.ZERO
	)

func _process(_delta):

	# Na Godot, o eixo Z do objeto aponta para trás
	# considerando que a frente dele seja -Z.
	var direcao_atras = cortador.global_transform.basis.z.normalized()


	# Calcula uma posição um pouco atrás do cortador.
	#
	# 🚜 -----> posição do círculo de corte
	var posicao_corte = (
		cortador.global_position
		+ direcao_atras * distancia_atras
	)


	# Converte a posição do círculo
	# para uma posição dentro da máscara.
	var posicao_mascara = mundo_para_mascara(posicao_corte)


	# Pinta o círculo.
	pintar(posicao_mascara)


	# Atualiza a textura.
	textura_mascara.update(mascara)


	# Verifica se 95% da grama foi cortada.
	verificar_vitoria()
