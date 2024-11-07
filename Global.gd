extends Node 

var player_master = null
var ui = null
var alive_players = []
var last_team = null
var game_over = false

# Nodo para persistencia
onready var Persistent_nodes = get_node("/root/Persistent_nodes")

func save_player_team(team):
	last_team = team

func check_team_elimination(team) -> void:
	var team_alive = false

	for player in alive_players:
		if player.team == team:
			team_alive = true
			break

	if not team_alive:
		end_game(team)

func end_game(eliminated_team) -> void:
	if game_over:  # Evitar que se ejecute múltiples veces
		return
		
	game_over = true
	var winning_team = "red" if eliminated_team == "blue" else "blue"
	
	# Si eres el servidor, iniciar el proceso de reinicio
	if get_tree().is_network_server():
		# Esperar unos segundos antes de reiniciar
		yield(get_tree().create_timer(5.0), "timeout")
		rpc("restart_game")
	
	print(eliminated_team + " ha sido eliminado. " + winning_team + " es el ganador!")

sync func restart_game():
	# Limpiar variables de estado
	game_over = false
	alive_players.clear()
	last_team = null
	player_master = null

	# Obtener todos los jugadores (incluyendo el local)
	var all_players = get_tree().get_nodes_in_group("Players")

	# Reiniciar la posición y estado de todos los jugadores
	for player in all_players:
		# Llama a reset_player en cada jugador
		player.rpc("reset_player")

func instance_node_at_location(node: Object, parent: Object, location: Vector2) -> Object:
	var node_instance = instance_node(node, parent)
	node_instance.global_position = location
	return node_instance

func instance_node(node: Object, parent: Object) -> Object:
	var node_instance = node.instance()
	parent.add_child(node_instance)
	return node_instance
	
func get_player_by_id(id):
	if Persistent_nodes.has_node(str(id)):
		return Persistent_nodes.get_node(str(id))
	return null

func get_spawn_position(team: String) -> Vector2:
	# Encuentra los puntos de aparición en función del equipo
	var spawn_points = get_tree().get_nodes_in_group("SpawnPoints")
	var team_spawn_points = []
	for spawn in spawn_points:
		if spawn.team == team:
			team_spawn_points.append(spawn)

	# Selecciona un punto aleatorio de aparición
	if team_spawn_points.size() > 0:
		return team_spawn_points[randi() % team_spawn_points.size()].global_position
	else:
		return Vector2.ZERO  # O algún valor predeterminado si no hay puntos de aparición

