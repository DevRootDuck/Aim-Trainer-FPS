extends Control

# ============================================================
# MultiplayerLobby
#
# Tela de multiplayer coop pensada pra jogar com amigos via VPN
# de LAN virtual (Radmin VPN, Hamachi, etc): o host cria o grupo
# e a tela mostra os IPs locais da máquina dele (pra identificar
# qual é o IP virtual da VPN e passar pros amigos); quem quer
# entrar digita esse IP direto. Depois mostra uma sala de espera
# com a lista de jogadores conectados; o host escolhe
# mapa/modo/dificuldade/limite de jogadores e inicia a partida
# para todo mundo.
#
# IMPORTANTE (avisado também na tela): todo mundo precisa estar
# conectado na mesma rede virtual da VPN antes de tentar entrar.
# ============================================================

var tabs: TabContainer
var name_input: LineEdit

var map_option: OptionButton
var mode_option: OptionButton
var difficulty_option: OptionButton
var max_players_slider: HSlider
var max_players_value_label: Label
var create_button: Button
var create_status_label: Label

var join_ip_input: LineEdit
var join_port_input: LineEdit
var join_button: Button
var join_status_label: Label

var waiting_room: Control
var host_ip_list_label: Label
var player_list_box: VBoxContainer
var start_button: Button
var leave_button: Button

var setup_area: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()

	NetworkManager.player_list_changed.connect(_refresh_player_list)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)


func _build_ui() -> void:
	var bg := UIStyle.make_background(self)
	add_child(bg)

	var title := UIStyle.make_title("Jogar Online (Coop)", 30)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-220, 40)
	title.custom_minimum_size = Vector2(440, 40)
	add_child(title)

	setup_area = Control.new()
	setup_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(setup_area)

	var panel := UIStyle.make_panel()
	panel.custom_minimum_size = Vector2(460, 420)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-230, -190)
	setup_area.add_child(panel)

	var outer_vbox := UIStyle.make_vbox(10)
	panel.add_child(outer_vbox)

	var name_row := UIStyle.make_hbox(10)
	name_row.add_child(UIStyle.make_row_label("Seu nome"))
	name_input = LineEdit.new()
	name_input.theme = UIStyle.theme
	name_input.text = NetworkManager.local_player_info.get("name", "Jogador")
	name_input.custom_minimum_size = Vector2(200, 34)
	name_row.add_child(name_input)
	outer_vbox.add_child(name_row)
	name_input.text_changed.connect(func(t): NetworkManager.local_player_info["name"] = t)

	tabs = TabContainer.new()
	tabs.theme = UIStyle.theme
	tabs.custom_minimum_size = Vector2(420, 320)
	outer_vbox.add_child(tabs)

	_build_create_tab()
	_build_join_tab()

	var back_button := UIStyle.make_button("Voltar")
	back_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back_button.position = Vector2(20, -60)
	setup_area.add_child(back_button)
	back_button.pressed.connect(_on_back_pressed)

	_build_waiting_room()
	waiting_room.visible = false


func _row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var hbox := UIStyle.make_hbox(10)
	hbox.add_child(UIStyle.make_row_label(label_text))
	hbox.add_child(control)
	parent.add_child(hbox)


func _build_create_tab() -> void:
	var vbox := UIStyle.make_vbox(10)
	vbox.name = "Criar Grupo"
	tabs.add_child(vbox)

	map_option = UIStyle.make_option_button()
	map_option.add_item("Arena Padrão", 0)
	_row(vbox, "Mapa", map_option)

	mode_option = UIStyle.make_option_button()
	for mode in GameManager.MODE_NAMES.keys():
		mode_option.add_item(GameManager.MODE_NAMES[mode], mode)
	mode_option.select(mode_option.get_item_index(GameManager.TrainMode.RANDOM_SPAWN))
	_row(vbox, "Modo", mode_option)

	difficulty_option = UIStyle.make_option_button()
	difficulty_option.add_item("Fácil", GameManager.Difficulty.EASY)
	difficulty_option.add_item("Médio", GameManager.Difficulty.MEDIUM)
	difficulty_option.add_item("Difícil", GameManager.Difficulty.HARD)
	difficulty_option.select(difficulty_option.get_item_index(GameManager.Difficulty.MEDIUM))
	_row(vbox, "Dificuldade", difficulty_option)

	max_players_slider = UIStyle.make_slider(NetworkManager.MIN_PLAYERS, NetworkManager.MAX_PLAYERS_LIMIT, 1.0, 4.0)
	max_players_value_label = UIStyle.make_label("4 jogadores")
	var slider_row := UIStyle.make_hbox(10)
	slider_row.add_child(UIStyle.make_row_label("Limite de jogadores"))
	slider_row.add_child(max_players_slider)
	slider_row.add_child(max_players_value_label)
	vbox.add_child(slider_row)
	max_players_slider.value_changed.connect(func(v):
		max_players_value_label.text = "%d jogadores" % int(v)
	)

	vbox.add_child(UIStyle.make_label("Conecte-se à sua VPN (Radmin/Hamachi) antes de criar.", true))

	create_button = UIStyle.make_button("Criar Grupo")
	vbox.add_child(create_button)
	create_button.pressed.connect(_on_create_pressed)

	create_status_label = UIStyle.make_label("", true)
	vbox.add_child(create_status_label)


func _build_join_tab() -> void:
	var vbox := UIStyle.make_vbox(10)
	vbox.name = "Entrar em Grupo"
	tabs.add_child(vbox)

	vbox.add_child(UIStyle.make_label("Digite o IP (da VPN) que o host te passou:"))

	join_ip_input = LineEdit.new()
	join_ip_input.theme = UIStyle.theme
	join_ip_input.placeholder_text = "Ex: 26.123.45.67"
	join_ip_input.custom_minimum_size = Vector2(200, 40)
	vbox.add_child(join_ip_input)

	var port_row := UIStyle.make_hbox(10)
	port_row.add_child(UIStyle.make_row_label("Porta"))
	join_port_input = LineEdit.new()
	join_port_input.theme = UIStyle.theme
	join_port_input.text = str(NetworkManager.DEFAULT_PORT)
	join_port_input.custom_minimum_size = Vector2(100, 34)
	port_row.add_child(join_port_input)
	vbox.add_child(port_row)

	join_button = UIStyle.make_button("Entrar em Grupo")
	vbox.add_child(join_button)
	join_button.pressed.connect(_on_join_pressed)

	join_status_label = UIStyle.make_label("", true)
	vbox.add_child(join_status_label)

	vbox.add_child(UIStyle.make_label("Você e o host precisam estar na mesma VPN", true))
	vbox.add_child(UIStyle.make_label("(Radmin VPN, Hamachi, etc) antes de entrar.", true))


func _build_waiting_room() -> void:
	waiting_room = Control.new()
	waiting_room.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(waiting_room)

	var panel := UIStyle.make_panel()
	panel.custom_minimum_size = Vector2(420, 400)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-210, -190)
	waiting_room.add_child(panel)

	var vbox := UIStyle.make_vbox(10)
	panel.add_child(vbox)

	vbox.add_child(UIStyle.make_title("Sala de Espera", 22))

	host_ip_list_label = UIStyle.make_label("")
	host_ip_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(host_ip_list_label)

	vbox.add_child(UIStyle.make_label("Jogadores:"))
	player_list_box = UIStyle.make_vbox(4)
	vbox.add_child(player_list_box)

	start_button = UIStyle.make_button("Iniciar Partida")
	vbox.add_child(start_button)
	start_button.pressed.connect(_on_start_pressed)

	leave_button = UIStyle.make_button("Sair do Grupo")
	vbox.add_child(leave_button)
	leave_button.pressed.connect(_on_leave_pressed)


# ---------------- Ações ----------------

func _on_create_pressed() -> void:
	create_button.disabled = true
	NetworkManager.local_player_info["name"] = name_input.text if not name_input.text.is_empty() else "Jogador"
	NetworkManager.selected_map = "arena_padrao"
	NetworkManager.selected_mode = mode_option.get_selected_id()
	NetworkManager.selected_difficulty = difficulty_option.get_selected_id()
	var chosen_max: int = int(max_players_slider.value)

	var err := NetworkManager.host_game(chosen_max)
	create_button.disabled = false
	if err != OK:
		create_status_label.text = "Erro ao criar o grupo (código %d). A porta %d já está em uso?" % [err, NetworkManager.DEFAULT_PORT]
		return
	AudioManager.play_ui()
	_enter_waiting_room()


func _on_join_pressed() -> void:
	var ip: String = join_ip_input.text.strip_edges()
	if not NetworkManager.is_valid_ip(ip):
		join_status_label.text = "Digite um IP válido, ex: 26.123.45.67"
		return
	var port: int = NetworkManager.DEFAULT_PORT
	if not join_port_input.text.strip_edges().is_empty() and join_port_input.text.strip_edges().is_valid_int():
		port = int(join_port_input.text.strip_edges())
	NetworkManager.local_player_info["name"] = name_input.text if not name_input.text.is_empty() else "Jogador"
	join_status_label.text = "Conectando..."
	join_button.disabled = true
	var err := NetworkManager.join_game_with_ip(ip, port)
	if err != OK:
		join_status_label.text = "Não foi possível iniciar a conexão."
		join_button.disabled = false
		return
	# a confirmação real vem por connection_succeeded / connection_failed


func _on_connection_succeeded() -> void:
	join_button.disabled = false
	AudioManager.play_ui()
	_enter_waiting_room()


func _on_connection_failed() -> void:
	join_button.disabled = false
	join_status_label.text = "Não foi possível conectar. Confira o código e a conexão do host."


func _on_server_disconnected() -> void:
	waiting_room.visible = false
	setup_area.visible = true
	create_status_label.text = "Conexão com o host perdida."


func _enter_waiting_room() -> void:
	setup_area.visible = false
	waiting_room.visible = true
	start_button.visible = NetworkManager.is_host
	if NetworkManager.is_host:
		var ips: PackedStringArray = NetworkManager.get_local_ips()
		if ips.is_empty():
			host_ip_list_label.text = "Grupo criado! Passe o IP da sua VPN pros amigos."
		else:
			host_ip_list_label.text = "Seus IPs (ache o da VPN e passe pros amigos):\n%s" % "\n".join(ips)
	else:
		host_ip_list_label.text = "Conectado! Aguardando o host iniciar..."
	_refresh_player_list()


func _refresh_player_list() -> void:
	for child in player_list_box.get_children():
		child.queue_free()
	for peer_id in NetworkManager.players.keys():
		var info: Dictionary = NetworkManager.players[peer_id]
		var tag: String = " (você)" if peer_id == multiplayer.get_unique_id() else ""
		var host_tag: String = " [host]" if peer_id == 1 else ""
		player_list_box.add_child(UIStyle.make_label("• %s%s%s" % [info.get("name", "Jogador"), host_tag, tag]))


func _on_start_pressed() -> void:
	AudioManager.play_ui()
	NetworkManager.start_match()


func _on_leave_pressed() -> void:
	AudioManager.play_ui()
	NetworkManager.leave_game()
	waiting_room.visible = false
	setup_area.visible = true
	create_status_label.text = ""
	join_status_label.text = ""


func _on_back_pressed() -> void:
	AudioManager.play_ui()
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
