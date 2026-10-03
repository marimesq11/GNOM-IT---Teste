class_name Spawner
extends Node3D

@export var tipos_inimigos: Array[DadosSpawnInimigo] = []
@export var pontos_spawn: Array[Marker3D] = []

@export_group("Jogador")
@export var jogador: CharacterBody3D

@export_group("Tempo")
@export var intervalo_checagem: float = 0.5

var cortador: CharacterBody3D


func _ready() -> void:
	# Procura o Cortador pelo grupo.
	cortador = get_tree().get_first_node_in_group("player") as CharacterBody3D

	print("CORTADOR ENCONTRADO: ", cortador)

	var timer: Timer = Timer.new()
	timer.wait_time = intervalo_checagem
	timer.autostart = true
	timer.timeout.connect(_checar_spawns)
	add_child(timer)

	call_deferred("_checar_spawns")


func _checar_spawns() -> void:
	for tipo in tipos_inimigos:

		if tipo == null:
			continue

		if tipo.cena == null:
			continue

		if tipo.grupo.is_empty():
			continue

		if _contar_vivos(tipo.grupo) < tipo.maximo:
			_spawnar(tipo)


func _contar_vivos(grupo: String) -> int:
	var total: int = 0

	for inimigo: Node in get_tree().get_nodes_in_group(grupo):

		if inimigo.is_queued_for_deletion():
			continue

		total += 1

	return total


func _spawnar(tipo: DadosSpawnInimigo) -> void:

	if pontos_spawn.is_empty():
		return

	var ponto: Marker3D = pontos_spawn.pick_random()

	if ponto == null or not ponto.is_inside_tree():
		return

	var inimigo: Node3D = tipo.cena.instantiate() as Node3D

	if inimigo == null:
		return

	# Passa o Cortador para o inimigo ANTES de colocá-lo na árvore.
	if "player" in inimigo:
		inimigo.player = cortador

	# Adiciona a cena do inimigo à cena principal.
	get_tree().current_scene.add_child(inimigo)

	# Posiciona depois de entrar na árvore.
	inimigo.global_position = ponto.global_position

	# Escala.
	var escala: float = randf_range(
		tipo.escala_min,
		tipo.escala_max
	)

	inimigo.scale = Vector3.ONE * escala

	# Grupo.
	inimigo.add_to_group(tipo.grupo)
