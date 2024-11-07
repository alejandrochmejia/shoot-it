extends Node

var player_master = null
var ui = null
var alive_players = []
var last_team = null
var game_over = false
var current_spawn_location_instance_number = 1
var current_player_for_spawn_location_number = null

func _ready() -> void:
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	
	if get_tree().is_network_server():
		setup_players_positions()

onready var Persistent_nodes = get_node("/root/Persistent_nodes")

func save_player_team(team):
	last_team = team

sync func restart_game():
	# Limpiar variables de estado
	game_over = false
	alive_players.clear()
	last_team = null
	player_master = null
	current_spawn_location_instance_number = 1
	current_player_for_spawn_location_number = null
	
	# Reiniciar todos los jugadores (vivos y muertos)
	for player in Persistent_nodes.get_children():
		if player.is_in_group("Player"):
			player.rpc("reset_player")  # Resetea el estado del jugador
			yield(get_tree().create_timer(0.1), "timeout")  # Espera un poco para evitar problemas de sincronización

	# Reposicionar todos los jugadores
	yield(get_tree().create_timer(0.1), "timeout")  # Espera un poco para asegurarte de que los jugadores se han reseteado
	setup_players_positions()
	
	# Reiniciar la UI
	if ui != null:
		ui.reset_game_ui()

func reset_lobby():
	current_spawn_location_instance_number = 1
	current_player_for_spawn_location_number = null
	
	for player in Persistent_nodes.get_children():
		if player.is_in_group("Player"):
			player.rpc("reset_player")
			yield(get_tree().create_timer(0.1), "timeout")
			setup_players_positions()

func setup_players_positions() -> void:
	current_spawn_location_instance_number = 1
	current_player_for_spawn_location_number = null
	
	for player in Persistent_nodes.get_children():
		if player.is_in_group("Player"):
			for spawn_location in get_tree().current_scene.get_node("Spawn_locations").get_children():
				if int(spawn_location.name) == current_spawn_location_instance_number and current_player_for_spawn_location_number != player:
					player.rpc("update_position", spawn_location.global_position)
					current_spawn_location_instance_number += 1
					current_player_for_spawn_location_number = player

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

func check_team_elimination(team: String) -> void:
	var team_alive = false
	for player in alive_players:
		if player.team == team and player.hp > 0:
			team_alive = true
			break
	
	if not team_alive and not game_over:
		game_over = true
		rpc("handle_game_over", team)

sync func handle_game_over(losing_team: String):
	var winning_team = "red" if losing_team == "blue" else "blue"
	if ui != null:
		ui.show_game_over(winning_team)
	
	# Esperar un momento antes de reiniciar
	yield(get_tree().create_timer(3.0), "timeout")
	rpc("restart_game")
	
func _player_disconnected(id) -> void:
	if Persistent_nodes.has_node(str(id)):
		var player = Persistent_nodes.get_node(str(id))
		if player.username_text_instance:
			player.username_text_instance.queue_free()
		player.queue_free()
		
		# Verificar si necesitamos reiniciar el juego
		if alive_players.size() <= 1:
			rpc("restart_game")
