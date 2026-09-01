extends MeshInstance3D


# ============================================
# REFERÊNCIAS DA CENA
# ============================================

# @onready faz essa variável ser preenchida
# quando o nó estiver pronto.
@onready var cortador = $"../../cortador"


# Pega o MultiMeshInstance3D que possui
# todas as lâminas de grama.
#
# IMPORTANTE:
# confira se o seu nó realmente se chama "Grama".
@onready var grama: MultiMeshInstance3D = $"../../MultiMeshInstance3D"


# ============================================
# CONFIGURAÇÕES DO CORTE
# ============================================

# Tamanho do círculo que corta a grama.
# Esse valor está em unidades do mundo.
@export var raio_corte: float = 0.18


# ============================================
# MÁSCARA
# ============================================

# Imagem que conseguimos modificar pelo GDScript.
#
# Nela:
# Branco = grama ainda existe
# Preto  = grama foi cortada
var mascara: Image


# Versão da Image que pode ser enviada
# para o shader.
var textura_mascara: ImageTexture


# Tamanho da nossa máscara.
const TAMANHO_MASCARA: int = 512


# Quantidade total de pixels.
#
# 512 x 512 = 262144 pixels
const TOTAL_PIXELS: int = TAMANHO_MASCARA * TAMANHO_MASCARA


# ============================================
# VITÓRIA
# ============================================

# Guarda quantos pixels da máscara
# já foram cortados.
var pixels_cortados: int = 0


# Impede que o print de vitória
# aconteça várias vezes.
var venceu: bool = false



# ============================================
# PINTAR O RASTRO
# ============================================

func pintar(posicao: Vector2):

	# Nosso terreno possui 20 unidades
	# e nossa máscara possui 512 pixels.
	#
	# Então:
	#
	# 512 / 20 = 25.6
	#
	# Cada unidade do mundo corresponde
	# aproximadamente a 25.6 pixels.
	var pixels_por_metro = 512.0 / 20.0


	# Converte o raio do cortador
	# de unidades do mundo para pixels.
	var raio_pixels = int(
		raio_corte * pixels_por_metro
	)


	# Centro do círculo dentro da máscara.
	var centro_x = int(posicao.x)
	var centro_y = int(posicao.y)


	# Calcula apenas a região próxima do círculo.
	#
	# Assim não precisamos verificar
	# todos os 512x512 pixels.
	var inicio_x = max(
		centro_x - raio_pixels,
		0
	)

	var fim_x = min(
		centro_x + raio_pixels,
		TAMANHO_MASCARA - 1
	)


	var inicio_y = max(
		centro_y - raio_pixels,
		0
	)

	var fim_y = min(
		centro_y + raio_pixels,
		TAMANHO_MASCARA - 1
	)


	# Percorre somente a área
	# próxima do cortador.
	for y in range(inicio_y, fim_y + 1):

		for x in range(inicio_x, fim_x + 1):

			# Calcula a distância entre
			# esse pixel e o centro do círculo.
			var distancia = Vector2(
				x,
				y
			).distance_to(posicao)


			# Se o pixel estiver dentro
			# do círculo...
			if distancia <= raio_pixels:

				# Verifica se esse pedaço
				# ainda não tinha sido cortado.
				#
				# Isso impede que o mesmo pixel
				# seja contado várias vezes.
				if mascara.get_pixel(x, y) != Color.BLACK:

					# Pinta o pixel de preto.
					#
					# No nosso shader:
					#
					# preto = esconder a grama
					mascara.set_pixel(
						x,
						y,
						Color.BLACK
					)


					# Conta mais um pixel cortado.
					pixels_cortados += 1



# ============================================
# MUNDO 3D -> MÁSCARA 2D
# ============================================

func mundo_para_mascara(posicao: Vector3) -> Vector2:

	# O cortador está no mundo 3D:
	#
	# X = esquerda / direita
	# Y = altura
	# Z = frente / trás
	#
	# Como nossa máscara é uma imagem 2D:
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
	# Primeiro fazemos:
	#
	# +10
	#
	# transformando:
	#
	# -10 até +10
	#
	# em:
	#
	# 0 até 20
	#
	#
	# Depois:
	#
	# /20
	#
	# transforma isso em uma porcentagem:
	#
	# 0 até 1
	#
	#
	# Finalmente:
	#
	# *512
	#
	# transforma essa porcentagem
	# em uma posição dentro da máscara.

	var x = (
		(posicao.x + 10.0)
		/ 20.0
		* TAMANHO_MASCARA
	)

	var y = (
		(posicao.z + 10.0)
		/ 20.0
		* TAMANHO_MASCARA
	)


	# Devolve a posição correspondente
	# dentro da máscara.
	return Vector2(x, y)



# ============================================
# VERIFICAR VITÓRIA
# ============================================

func verificar_vitoria():

	# Se já venceu, não precisa
	# verificar novamente.
	if venceu:
		return


	# Calcula a porcentagem cortada.
	#
	# pixels cortados
	# ----------------
	# pixels totais
	var porcentagem = (
		float(pixels_cortados)
		/
		float(TOTAL_PIXELS)
	)


	# 0.95 = 95%
	if porcentagem >= 0.95:

		venceu = true

		print("VITÓRIA! 95% da grama foi cortada!")



# ============================================
# CRIANDO A MÁSCARA
# ============================================

func _ready():

	# Cria uma imagem de 512x512 pixels.
	#
	# false = não utilizar mipmaps.
	mascara = Image.create(
		TAMANHO_MASCARA,
		TAMANHO_MASCARA,
		false,
		Image.FORMAT_RGBA8
	)


	# Começa com a máscara inteira branca.
	#
	# No shader:
	#
	# branco = grama aparece
	# preto  = grama desaparece
	mascara.fill(Color.WHITE)


	# Até aqui "mascara" é uma Image
	# que o GDScript consegue modificar.
	#
	# Agora transformamos ela em uma
	# ImageTexture para o shader conseguir usar.
	textura_mascara = ImageTexture.create_from_image(
		mascara
	)


	# ============================================
	# CONECTANDO A MÁSCARA COM O SHADER DA GRAMA
	# ============================================

	# Pega o ShaderMaterial colocado no
	# Material Override do MultiMeshInstance3D.
	var material = grama.material_override as ShaderMaterial


	# Verifica se conseguimos encontrar
	# o ShaderMaterial.
	if material == null:

		print("ERRO: não encontrei o ShaderMaterial da grama!")

		return


	# Envia nossa ImageTexture para:
	#
	# uniform sampler2D mascara;
	#
	# que adicionamos no shader da grama.
	material.set_shader_parameter(
		"mascara",
		textura_mascara
	)


	print("Máscara enviada para o shader da grama!")



# ============================================
# RASTRO DO CORTADOR
# ============================================

func _process(_delta):

	# Pega a posição atual do cortador
	# no mundo 3D.
	var posicao_corte = cortador.global_position


	# Converte a posição do mundo
	# para a posição correspondente
	# dentro da máscara.
	var posicao_mascara = mundo_para_mascara(
		posicao_corte
	)


	# Pinta um círculo preto
	# na posição do cortador.
	pintar(
		posicao_mascara
	)


	# Nós modificamos a Image no GDScript.
	#
	# Agora precisamos atualizar a
	# ImageTexture que está no shader.
	textura_mascara.update(
		mascara
	)


	# Verifica se 95% da grama
	# já foi cortada.
	verificar_vitoria()
