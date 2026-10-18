
extends Node

# ==================================================
# SISTEMA DE PONTUAÇÃO ORIGINAL
# ==================================================

var pontos: int = 0

var popup_pontos = preload("res://Cenas/PopupPontos.tscn")


func adicionar_pontos(valor: int, posicao_3d: Vector3) -> void:
	pontos += valor
	print("pontos agora: ", pontos)

	var popup = popup_pontos.instantiate()
	get_tree().current_scene.add_child(popup)
	popup.global_position = posicao_3d
	popup.aparecer("+" + str(valor))


# ==================================================
# CONFIGURAÇÕES DA AVALIAÇÃO
# ==================================================

# Metas para conseguir 100% em cada categoria.
var meta_gnomos: int = 25
var meta_objetos: int = 15
var meta_objetivos: int = 3

# Ativar quando o sistema de grama estiver pronto.
var avaliar_grama: bool = false

# Limites das estrelas.
var limite_2_estrelas: float = 45.0
var limite_3_estrelas: float = 80.0


# ==================================================
# PROGRESSO DA FASE
# ==================================================

var gnomos_destruidos: int = 0
var objetos_destruidos: int = 0
var objetivos_concluidos: int = 0

var porcentagem_grama: float = 0.0


# ==================================================
# REGISTRAR AÇÕES
# ==================================================

func registrar_gnomo() -> void:
	gnomos_destruidos += 1


func registrar_objeto() -> void:
	objetos_destruidos += 1


func registrar_objetivo() -> void:
	objetivos_concluidos += 1


func atualizar_grama(porcentagem: float) -> void:
	porcentagem_grama = clampf(porcentagem, 0.0, 100.0)


# ==================================================
# CALCULAR NOTAS INDIVIDUAIS
# ==================================================

func calcular_nota_gnomos() -> float:
	if meta_gnomos <= 0:
		return 100.0

	return minf(
		float(gnomos_destruidos) / float(meta_gnomos) * 100.0,
		100.0
	)


func calcular_nota_objetos() -> float:
	if meta_objetos <= 0:
		return 100.0

	return minf(
		float(objetos_destruidos) / float(meta_objetos) * 100.0,
		100.0
	)


func calcular_nota_objetivos() -> float:
	if meta_objetivos <= 0:
		return 100.0

	return minf(
		float(objetivos_concluidos) / float(meta_objetivos) * 100.0,
		100.0
	)


func calcular_nota_cenario() -> float:
	return calcular_nota_objetos()


# ==================================================
# CALCULAR DESEMPENHO GERAL
# ==================================================

func calcular_desempenho() -> float:
	var nota_gnomos = calcular_nota_gnomos()
	var nota_cenario = calcular_nota_cenario()

	# Enquanto a grama estiver desativada,
	# calcula a média apenas de duas categorias.
	if not avaliar_grama:
		return (nota_gnomos + nota_cenario) / 2.0

	# Quando a grama estiver ativada,
	# calcula a média das três categorias.
	return (
		nota_gnomos +
		nota_cenario +
		porcentagem_grama
	) / 3.0


# ==================================================
# CALCULAR ESTRELAS
# ==================================================

func calcular_estrelas() -> int:
	var desempenho = calcular_desempenho()

	if desempenho >= limite_3_estrelas:
		return 3

	if desempenho >= limite_2_estrelas:
		return 2

	return 1


# ==================================================
# REINICIAR PONTUAÇÃO E AVALIAÇÃO
# ==================================================

func reiniciar() -> void:
	pontos = 0
	gnomos_destruidos = 0
	objetos_destruidos = 0
	objetivos_concluidos = 0
	porcentagem_grama = 0.0
