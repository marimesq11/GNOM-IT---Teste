extends MeshInstance3D

#Pega o cortador na cena
#@onready faz essa variável ser preenchida quando o nó estiver pronto
@onready var cortador = $"../../cortador"

#Imagem que podemos modificar pelo código
var mascara: Image

#Versão da Image que pode ser enviada para o shader
var textura_mascara: ImageTexture

# posicao -> onde queremos pintar na imagem
# raio    -> tamanho do círculo que será pintado
func pintar(posicao: Vector2, raio: int):
	#Percorre toda a extensao da imagem
	#linhas
	for y in range(512):
		#colunas
		for x in range(512):
			
			# Cria a posição do pixel atual: (x, y)
			# e calcula a distância dele até o centro
			# que recebemos em "posicao".
			var distancia = Vector2(x, y).distance_to(posicao)
			
			#Se o pixel estiver dentro do raio do círculo
			if distancia <= raio:
				#transforma esse pixel em preto
				# No nosso shader, preto significa:
				# "mostrar a textura de baixo".
				mascara.set_pixel(x, y, Color.BLACK)


func mundo_para_mascara(posicao: Vector3) -> Vector2:
	# O cortador possui X,Y,Z Pq é 3D
	#A mascara é 2D ent ela tem so X,Y
	
	# Nosso terreno possui 20 unidades de tamanho
	# No mundo:
	# -10 -------- 0 -------- +10
	# Na máscara:
	#   0 ------- 256 -------- 512
	# Essa conta converte de -10/+10 para 0/512.
	var x = (posicao.x + 10.0) / 20.0 * 512.0
	var y = (posicao.z + 10.0) / 20.0 * 512.0

	# Fazemos a mesma coisa com Z.
	# Usamos Z porque estamos trabalhando com um chão 3D.
	# X representa um lado do chão e Z representa o outro.
	# O Y do mundo representa altura, então não precisamos dele.
	# Devolve a posição correspondente dentro da máscara

	return Vector2(x, y)
	

func _ready():
	# Cria uma imagem de 512x512 pixels.
	# false = não usar mipmaps.
	mascara = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	mascara.fill(Color.WHITE)

	var posicao_cortador = cortador.global_position
	var posicao_mascara = mundo_para_mascara(posicao_cortador)

	#50 == Raio do circulo
	pintar(posicao_mascara, 50)

	# Até aqui "mascara" é uma Image que o GDScript
	# consegue modificar.
	# Agora transformamos ela em uma ImageTexture
	# para o shader conseguir utilizá-la.
	textura_mascara = ImageTexture.create_from_image(mascara)

	# Pega o ShaderMaterial que colocamos na
	# Surface Material Override 0 do MeshInstance3D.
	var material = get_surface_override_material(0) as ShaderMaterial
	#Coloca essa mascara no slot vazio de mascara no Shader
	material.set_shader_parameter("mascara", textura_mascara)

#Grid em cima da textura para calcular oq foi destruido
