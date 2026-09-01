extends Node

# ============================================================
# GameManager (Autoload / Singleton)
#
# Controla o estado geral do jogo: modo de treino ativo,
# dificuldade, estatísticas da sessão (tiros, acertos, headshots,
# kills, tempo de reação) e a troca entre cenas.
# ============================================================

signal stats_updated
signal training_finished
signal headshot_landed

enum Difficulty { EASY, MEDIUM, HARD }
enum GameState { MENU, PLAYING, PAUSED, RESULTS }

enum TrainMode {
	FREE_PLAY,      # Treino Livre - sem cronômetro, sem fim
	STATIC,         # Alvos Estáticos
	RANDOM_SPAWN,   # Alvos Aleatórios (aparecem/somem em posições aleatórias)
	MOVING,         # Alvos Móveis (andam/correm)
	REFLEX,         # Reflexo - aparecem por muito pouco tempo
	SURVIVAL,       # Sobrevivência - perde ao errar demais
	HEADSHOT_ONLY,  # Só conta headshot
	PRECISION,      # Munição limitada, foco em não desperdiçar
	TIMED           # Cronometrado - pontuação máxima no tempo
}

const MODE_NAMES := {
	TrainMode.FREE_PLAY: "Treino Livre",
	TrainMode.STATIC: "Alvos Estáticos",
	TrainMode.RANDOM_SPAWN: "Alvos Aleatórios",
	TrainMode.MOVING: "Alvos Móveis",
	TrainMode.REFLEX: "Reflexo",
	TrainMode.SURVIVAL: "Sobrevivência",
	TrainMode.HEADSHOT_ONLY: "Headshot Only",
	TrainMode.PRECISION: "Precisão",
	TrainMode.TIMED: "Cronometrado"
}

var difficulty_settings := {
	Difficulty.EASY: {
		"name": "Fácil", "target_lifetime": 3.0, "target_scale": 1.2,
		"spawn_interval": 1.2, "training_duration": 60.0, "max_targets": 2,
		"move_speed": 1.2
	},
	Difficulty.MEDIUM: {
		"name": "Médio", "target_lifetime": 2.0, "target_scale": 1.0,
		"spawn_interval": 0.9, "training_duration": 60.0, "max_targets": 3,
		"move_speed": 2.0
	},
	Difficulty.HARD: {
		"name": "Difícil", "target_lifetime": 1.1, "target_scale": 0.85,
		"spawn_interval": 0.5, "training_duration": 60.0, "max_targets": 4,
		"move_speed": 3.2
	}
}

var current_difficulty: Difficulty = Difficulty.MEDIUM
var current_mode: TrainMode = TrainMode.RANDOM_SPAWN
var current_state: GameState = GameState.MENU
var selected_character: String = "eva"  # "eva" ou "adao"

# --- Estatísticas da sessão atual ---
var shots_fired: int = 0
var hits: int = 0
var misses: int = 0
var headshots: int = 0
var kills: int = 0
var lives_remaining: int = 3  # usado no modo Sobrevivência
var reaction_times: Array = []
var training_time_elapsed: float = 0.0
var training_time_total: float = 60.0

var _training_active: bool = false


func start_training(difficulty: Difficulty, mode: TrainMode = TrainMode.RANDOM_SPAWN) -> void:
	current_difficulty = difficulty
	current_mode = mode
	shots_fired = 0
	hits = 0
	misses = 0
	headshots = 0
	kills = 0
	lives_remaining = 3
	reaction_times.clear()
	training_time_elapsed = 0.0
	training_time_total = difficulty_settings[difficulty]["training_duration"]
	current_state = GameState.PLAYING
	_training_active = (mode != TrainMode.FREE_PLAY)

	get_tree().change_scene_to_file("res://scenes/arena/Arena.tscn")


func register_shot() -> void:
	shots_fired += 1
	emit_signal("stats_updated")


func register_hit(reaction_time: float, is_headshot: bool = false) -> void:
	hits += 1
	reaction_times.append(reaction_time)
	if is_headshot:
		headshots += 1
		emit_signal("headshot_landed")
	if current_mode != TrainMode.HEADSHOT_ONLY or is_headshot:
		kills += 1
	emit_signal("stats_updated")


func register_miss() -> void:
	misses += 1
	if current_mode == TrainMode.SURVIVAL:
		lives_remaining -= 1
		if lives_remaining <= 0:
			finish_training()
	emit_signal("stats_updated")


func update_timer(delta: float) -> void:
	if not _training_active:
		return
	training_time_elapsed += delta
	if training_time_elapsed >= training_time_total:
		finish_training()


func finish_training() -> void:
	_training_active = false
	current_state = GameState.RESULTS
	emit_signal("training_finished")
	get_tree().change_scene_to_file("res://scenes/results/ResultsScreen.tscn")


func get_accuracy() -> float:
	if shots_fired == 0:
		return 0.0
	return (float(hits) / float(shots_fired)) * 100.0


func get_average_reaction_time() -> float:
	if reaction_times.is_empty():
		return 0.0
	var total := 0.0
	for t in reaction_times:
		total += t
	return total / reaction_times.size()


func get_current_settings() -> Dictionary:
	return difficulty_settings[current_difficulty]


func get_mode_name() -> String:
	return MODE_NAMES.get(current_mode, "—")


func go_to_menu() -> void:
	current_state = GameState.MENU
	if NetworkManager.is_multiplayer_active:
		NetworkManager.leave_game()
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")


func restart_training() -> void:
	start_training(current_difficulty, current_mode)
