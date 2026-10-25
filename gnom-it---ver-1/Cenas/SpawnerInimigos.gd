
extends Node3D

# =========================================================
# CENAS DOS INIMIGOS
# =========================================================

@export var inimigo_1: PackedScene
@export var inimigo_2: PackedScene
@export var inimigo_3: PackedScene
@export var inimigo_4: PackedScene


# =========================================================
# LIMITES INDIVIDUAIS
# =========================================================

@export var max_inimigo_1: int = 5
@export var max_inimigo_2: int = 4
@export var max_inimigo_3: int = 3
@export var max_inimigo_4: int = 2


# =========================================================
# ESCALAS INDIVIDUAIS
# =========================================================

@export var escala_inimigo_1: float = 1.0
@export var escala_inimigo_2: float = 1.0
@export var escala_inimigo_3: float = 1.0
@export var escala_inimigo_4: float = 1.0


# =========================================================
# CONFIGURAÇÕES
# =========================================================

@export var intervalo_spawn: float = 5.0
@export var spawn_automatico: bool = true


# =========================================================
# REFERÊNCIA DA GRAMA
# =========================================================

@export var sistema_grama: SistemaGrama


# =========================================================
# PONTOS DE SPAWN
# =========================================================

@export var marker_1: Marker3D
@export var marker_2: Marker3D
@export var marker_3: Marker3D


# =========================================================
# CONTROLE
# =========================================================

var inimigos_vivos: Array = [[], [], [], []]
var tempo: float = 0.0
var jogador: Node3D


# =========================================================
# INICIALIZAÇÃO
# =========================================================

func _ready() -> void:
	randomize()
	procurar_jogador()


func procurar_jogador() -> void:
	jogador = get_tree().get_first_node_in_group("player") as Node3D

	if jogador:
		print("SPAWNER: Jogador encontrado: ", jogador.name)
	else:
		print("ERRO: Jogador não encontrado!")


# =========================================================
# PROCESSO
# =========================================================

func _process(delta: float) -> void:
	if not spawn_automatico:
		return

	tempo += delta

	if tempo >= intervalo_spawn:
		tempo = 0.0
		spawnar_inimigo()


# =========================================================
# SPAWN
# =========================================================

func spawnar_inimigo() -> void:

	var cenas = [
		inimigo_1,
		inimigo_2,
		inimigo_3,
		inimigo_4
	]

	var limites = [
		max_inimigo_1,
		max_inimigo_2,
		max_inimigo_3,
		max_inimigo_4
	]

	var escalas = [
		escala_inimigo_1,
		escala_inimigo_2,
		escala_inimigo_3,
		escala_inimigo_4
	]

	# Pontos disponíveis
	var markers: Array[Marker3D] = []

	for marker in [marker_1, marker_2, marker_3]:
		if is_instance_valid(marker):
			markers.append(marker)

	if markers.is_empty():
		print("ERRO: Nenhum Marker3D configurado!")
		return

	# Limpa inimigos destruídos
	for i in range(4):
		inimigos_vivos[i] = inimigos_vivos[i].filter(
			func(inimigo): return is_instance_valid(inimigo)
		)

	# Verifica tipos disponíveis
	var tipos_disponiveis: Array[int] = []

	for i in range(4):
		if cenas[i] != null and inimigos_vivos[i].size() < limites[i]:
			tipos_disponiveis.append(i)

	if tipos_disponiveis.is_empty():
		print("SPAWNER: Todos os limites foram atingidos!")
		return

	# Escolhas aleatórias
	var tipo = tipos_disponiveis.pick_random()
	var marker = markers.pick_random()

	# Atualiza referência do jogador
	if not is_instance_valid(jogador):
		procurar_jogador()

	# Cria inimigo
	var inimigo = cenas[tipo].instantiate() as Node3D

	if inimigo == null:
		print("ERRO: Cena do inimigo inválida!")
		return

	# =====================================================
	# CONFIGURA REFERÊNCIAS
	# =====================================================

	var recebeu_referencia = false

	for propriedade in inimigo.get_property_list():

		# Inimigos que usam o Cortador
		if propriedade.name == "Cortador":

			if is_instance_valid(jogador):
				inimigo.set("Cortador", jogador)
				recebeu_referencia = true

		# Inimigos que usam o sistema de grama
		elif propriedade.name == "sistema_grama":

			if is_instance_valid(sistema_grama):
				inimigo.set("sistema_grama", sistema_grama)
				recebeu_referencia = true
			else:
				push_warning(
					"SPAWNER: Sistema de grama não configurado!"
				)

	if not recebeu_referencia:
		print(
			"AVISO: Inimigo ",
			tipo + 1,
			" não recebeu referência externa!"
		)

	# =====================================================
	# ADICIONA À CENA
	# =====================================================

	get_parent().add_child(inimigo)

	# Posição
	inimigo.global_position = marker.global_position

	# Escala individual
	inimigo.scale *= escalas[tipo]

	# =====================================================
	# REGISTRA INIMIGO
	# =====================================================

	inimigos_vivos[tipo].append(inimigo)

	print(
		"SPAWN: Inimigo ", tipo + 1,
		" | Ponto: ", marker.name,
		" | Vivos: ", inimigos_vivos[tipo].size(),
		"/", limites[tipo],
		" | Escala: ", inimigo.scale
	)


# =========================================================
# LIMPEZA
# =========================================================

func _exit_tree() -> void:
	for lista in inimigos_vivos:
		lista.clear()
