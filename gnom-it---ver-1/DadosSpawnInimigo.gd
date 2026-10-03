class_name DadosSpawnInimigo
extends Resource
 
## Cena do inimigo (.tscn)
@export var cena: PackedScene
## Nome do grupo usado para contar esse tipo (ex: "inimigo_zumbi")
@export var grupo: String = ""
## Quantidade máxima desse tipo ao mesmo tempo na cena
@export var maximo: int = 5
 
@export_group("Escala")
## Escala mínima com que o inimigo aparece (1.0 = tamanho original)
@export var escala_min: float = 0.055
## Escala máxima. Se for igual à mínima, todos nascem do mesmo tamanho.
@export var escala_max: float = 0.06
