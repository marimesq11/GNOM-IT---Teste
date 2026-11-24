
extends CanvasLayer

@export_file("*.tscn") var cena_menu_principal: String

@export var fundo: ColorRect
@export var titulo: Label
@export var esc_sair: Label
@export var botao_menu: Button
@export var botao_sair: Button
@onready var contagem: Label = %Contagem

var pausado: bool = false
var contando: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	# Garante que o fundo não bloqueie os cliques
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Permite que os botões funcionem durante a pausa
	botao_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	botao_sair.process_mode = Node.PROCESS_MODE_ALWAYS

	# Conecta os botões
	if not botao_menu.pressed.is_connected(ir_para_menu):
		botao_menu.pressed.connect(ir_para_menu)

	if not botao_sair.pressed.is_connected(sair_do_jogo):
		botao_sair.pressed.connect(sair_do_jogo)


	esconder_menu()
	contagem.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()

			if contando:
				return

			if pausado:
				continuar_jogo()
			else:
				pausar_jogo()


# ==================================================
# PAUSAR
# ==================================================

func pausar_jogo() -> void:
	pausado = true
	get_tree().paused = true

	fundo.visible = true
	titulo.visible = true
	esc_sair.visible = true
	botao_menu.visible = true
	botao_sair.visible = true

	contagem.visible = false


# ==================================================
# CONTINUAR
# ==================================================

func continuar_jogo() -> void:
	if contando:
		return

	contando = true

	titulo.visible = false
	esc_sair.visible = false
	botao_menu.visible = false
	botao_sair.visible = false

	fundo.visible = true
	contagem.visible = true

	for numero in ["3", "2", "1"]:
		contagem.text = numero
		await get_tree().create_timer(1.0, true).timeout

	contagem.visible = false
	fundo.visible = false

	contando = false
	pausado = false

	get_tree().paused = false


# ==================================================
# ESCONDER MENU
# ==================================================

func esconder_menu() -> void:
	fundo.visible = false
	titulo.visible = false
	esc_sair.visible = false
	botao_menu.visible = false
	botao_sair.visible = false


# ==================================================
# BOTAO MENU
# ==================================================

func ir_para_menu() -> void:
	get_tree().paused = false

	if cena_menu_principal != "":
		get_tree().change_scene_to_file(cena_menu_principal)


# ==================================================
# BOTAO SAIR
# ==================================================

func sair_do_jogo() -> void:
	get_tree().quit()
