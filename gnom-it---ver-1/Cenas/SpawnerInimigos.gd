
extends Node3D

@export var cena_inimigo: PackedScene
@export var intervalo_spawn: float = 5.0
@export var max_inimigos: int = 10
@export var spawn_automatico: bool = true

var inimigos: Array[Node3D] = []
var tempo: float = 0.0
var jogador: Node3D


func _ready() -> void:
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
	if cena_inimigo == null:
		print("ERRO: Cena do inimigo não configurada!")
		return

	# Remove inimigos que já foram destruídos
	inimigos = inimigos.filter(
		func(inimigo): return is_instance_valid(inimigo)
	)

	if inimigos.size() >= max_inimigos:
		return

	# Procura o jogador novamente, se necessário
	if not is_instance_valid(jogador):
		procurar_jogador()

	if not is_instance_valid(jogador):
		print("ERRO: Não foi possível encontrar o cortador!")
		return

	# Cria o inimigo
	var inimigo = cena_inimigo.instantiate() as Node3D

	if inimigo == null:
		print("ERRO: O inimigo precisa ser um Node3D!")
		return

	# Passa o cortador ANTES do _ready()
	var recebeu_cortador: bool = false

	for propriedade in inimigo.get_property_list():
		if propriedade.name == "Cortador":
			inimigo.set("Cortador", jogador)
			recebeu_cortador = true
			print("CORTADOR ATRIBUÍDO: ", jogador.name)
			break

	if not recebeu_cortador:
		print("AVISO: Inimigo não possui propriedade Cortador!")

	# Adiciona como irmão do spawner
	get_parent().add_child(inimigo)

	# Posiciona o inimigo no spawner
	inimigo.global_position = global_position

	# Registra o inimigo criado
	inimigos.append(inimigo)

	print("INIMIGO CRIADO: ", inimigo.name)
	print("REFERÊNCIA CORTADOR: ", inimigo.get("Cortador") if recebeu_cortador else "Não encontrada")


func _exit_tree() -> void:
	inimigos.clear()
