
extends Node3D

# CENAS DOS INIMIGOS
@export var inimigo_1: PackedScene
@export var inimigo_2: PackedScene
@export var inimigo_3: PackedScene
@export var inimigo_4: PackedScene

# LIMITES INDIVIDUAIS
@export var max_inimigo_1: int = 5
@export var max_inimigo_2: int = 4
@export var max_inimigo_3: int = 3
@export var max_inimigo_4: int = 2

# CONFIGURAÇÕES
@export var intervalo_spawn: float = 5.0
@export var spawn_automatico: bool = true

# PONTOS DE SPAWN
@export var marker_1: Marker3D
@export var marker_2: Marker3D
@export var marker_3: Marker3D

# CONTROLE
var inimigos_vivos: Array = [[], [], [], []]
var tempo: float = 0.0
var jogador: Node3D


func _ready() -> void:
	randomize()
	procurar_jogador()


func procurar_jogador() -> void:
	jogador = get_tree().get_first_node_in_group("player") as Node3D

	if jogador:
		print("SPAWNER: Jogador encontrado: ", jogador.name)
	else:
		print("ERRO: Jogador não encontrado!")


func _process(delta: float) -> void:
	if not spawn_automatico:
		return

	tempo += delta

	if tempo >= intervalo_spawn:
		tempo = 0.0
		spawnar_inimigo()


func spawnar_inimigo() -> void:

	# Cenas disponíveis
	var cenas = [
		inimigo_1,
		inimigo_2,
		inimigo_3,
		inimigo_4
	]

	# Limites individuais
	var limites = [
		max_inimigo_1,
		max_inimigo_2,
		max_inimigo_3,
		max_inimigo_4
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

	# Verifica quais tipos podem spawnar
	var tipos_disponiveis: Array[int] = []

	for i in range(4):
		if cenas[i] != null and inimigos_vivos[i].size() < limites[i]:
			tipos_disponiveis.append(i)

	if tipos_disponiveis.is_empty():
		print("SPAWNER: Todos os limites foram atingidos!")
		return

	# Escolhe tipo aleatório
	var tipo = tipos_disponiveis.pick_random()

	# Escolhe ponto aleatório
	var marker = markers.pick_random()

	# Procura o jogador
	if not is_instance_valid(jogador):
		procurar_jogador()

	if not is_instance_valid(jogador):
		return

	# Cria o inimigo
	var inimigo = cenas[tipo].instantiate() as Node3D

	if inimigo == null:
		print("ERRO: Cena do inimigo inválida!")
		return

	# Passa o cortador antes do _ready()
	var recebeu_cortador = false

	for propriedade in inimigo.get_property_list():
		if propriedade.name == "Cortador":
			inimigo.set("Cortador", jogador)
			recebeu_cortador = true
			break

	if not recebeu_cortador:
		print("AVISO: Inimigo não possui propriedade Cortador!")

	# Adiciona como irmão do spawner
	get_parent().add_child(inimigo)

	# Posiciona no marker escolhido
	inimigo.global_position = marker.global_position

	# Registra inimigo
	inimigos_vivos[tipo].append(inimigo)

	print(
		"SPAWN: Inimigo ", tipo + 1,
		" | Ponto: ", marker.name,
		" | Vivos: ", inimigos_vivos[tipo].size(),
		"/", limites[tipo]
	)


func _exit_tree() -> void:
	for lista in inimigos_vivos:
		lista.clear()
