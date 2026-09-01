extends Node

# ============================================================
# NetworkManager (Autoload / Singleton)
#
# Multiplayer coop por IP direto (ENet). Pensado pra jogar com
# amigos por fora da mesma rede física usando uma VPN de LAN
# virtual (ex: Radmin VPN, Hamachi): todo mundo entra na mesma
# rede virtual e joga usando o IP virtual de cada um (tipo
# 26.x.x.x), sem precisar abrir porta no roteador. O host cria
# o grupo e vê a lista dos seus IPs locais (pra identificar o IP
# da VPN); quem quer entrar só digita esse IP.
# ============================================================

signal player_list_changed
signal connection_failed
signal connection_succeeded
signal server_disconnected
signal match_starting

const DEFAULT_PORT := 8910
const MIN_PLAYERS := 2
const MAX_PLAYERS_LIMIT := 50

var is_multiplayer_active: bool = false
var is_host: bool = false
var max_players: int = 4

var local_player_info: Dictionary = {"name": "Jogador", "character": "eva"}
var players: Dictionary = {}  # peer_id -> {name, character}

# Configuração da partida escolhida pelo host na sala de espera
var selected_mode: int = GameManager.TrainMode.RANDOM_SPAWN
var selected_difficulty: int = GameManager.Difficulty.MEDIUM
var selected_map: String = "arena_padrao"


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ---------------- IPs locais (pra identificar o IP da VPN) ----------------

func is_valid_ip(ip: String) -> bool:
	var parts: PackedStringArray = ip.strip_edges().split(".")
	if parts.size() != 4:
		return false
	for p in parts:
		if not p.is_valid_int():
			return false
		var n: int = int(p)
		if n < 0 or n > 255:
			return false
	return true


# Lista os IPs locais da máquina (Wi-Fi, Ethernet, adaptadores de VPN
# como Radmin/Hamachi) pra ajudar o host a achar qual deles é o IP
# virtual da VPN que ele deve passar pros amigos.
func get_local_ips() -> PackedStringArray:
	var result: PackedStringArray = []
	for ip in IP.get_local_addresses():
		if ip.is_valid_ip_address() and not ip.begins_with("127.") and ":" not in ip:
			result.append(ip)
	return result


# ---------------- Hospedar / Entrar ----------------

func host_game(max_p: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(DEFAULT_PORT, clamp(max_p, MIN_PLAYERS, MAX_PLAYERS_LIMIT))
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_multiplayer_active = true
	is_host = true
	max_players = max_p
	players.clear()
	players[1] = local_player_info.duplicate()
	emit_signal("player_list_changed")
	return OK


func join_game_with_ip(ip: String, port: int = DEFAULT_PORT) -> Error:
	if not is_valid_ip(ip):
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_multiplayer_active = true
	is_host = false
	return OK


func leave_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_multiplayer_active = false
	is_host = false
	players.clear()


# ---------------- Sincronização de jogadores ----------------

func _on_peer_connected(_id: int) -> void:
	pass  # esperamos o novo peer se anunciar via _register_player_info


func _on_peer_disconnected(id: int) -> void:
	if is_host and players.has(id):
		players.erase(id)
		_sync_player_list.rpc(players)
		emit_signal("player_list_changed")


func _on_connected_to_server() -> void:
	emit_signal("connection_succeeded")
	_register_player_info.rpc_id(1, local_player_info)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	is_multiplayer_active = false
	emit_signal("connection_failed")


func _on_server_disconnected() -> void:
	leave_game()
	emit_signal("server_disconnected")
	GameManager.current_state = GameManager.GameState.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")


@rpc("any_peer", "reliable")
func _register_player_info(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	players[sender_id] = info
	_sync_player_list.rpc(players)
	emit_signal("player_list_changed")


@rpc("authority", "call_local", "reliable")
func _sync_player_list(new_players: Dictionary) -> void:
	players = new_players
	emit_signal("player_list_changed")


# ---------------- Iniciar partida ----------------

func start_match() -> void:
	if not is_host:
		return
	_begin_match.rpc(selected_mode, selected_difficulty)


@rpc("authority", "call_local", "reliable")
func _begin_match(mode: int, difficulty: int) -> void:
	emit_signal("match_starting")
	GameManager.start_training(difficulty as GameManager.Difficulty, mode as GameManager.TrainMode)
