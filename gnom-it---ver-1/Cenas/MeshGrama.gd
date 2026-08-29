extends MeshInstance3D


# @onready faz essa variável ser preenchida quando o nó estiver pronto.
@onready var cortador = $"../../cortador/Node3D"


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
	
	# Cria uma imagem de 512x512 pixels.
	# false = não usar mipmaps.
	mascara = Image.create(
		512,
		512,
		false,
		Image.FORMAT_RGBA8
	)
	
	
	# Começa com a máscara inteira branca.
	# No shader branco = grama
	mascara.fill(Color.WHITE)
	
	# Transforma a Image em uma ImageTexture
	# para o shader conseguir utilizá-la.
	textura_mascara = ImageTexture.create_from_image(mascara)
	
	# Pega o ShaderMaterial que está no
	# Surface Material Override 0.
	var material = get_surface_override_material(0) as ShaderMaterial
	
	
	# Coloca nossa máscara no parâmetro
	# "mascara" que existe no shader.
	material.set_shader_parameter(
		"mascara",
		textura_mascara
	)



# RASTRO DO CORTADOR

# RASTRO DO CORTADOR

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
