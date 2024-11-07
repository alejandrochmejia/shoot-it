extends Control

var player = load("res://Player.tscn")
var current_spawn_location_instance_number = 1
var current_player_for_spawn_location_number = null
var team_counts = {"red": 0, "blue": 0}

onready var multiplayer_config_ui = $Multiplayer_configure
onready var username_text_edit = $Multiplayer_configure/Username_text_edit
onready var device_ip_address = $UI/Device_ip_address
onready var start_game = $UI/Start_game
onready var Persistent_nodes = get_node("/root/Persistent_nodes")  # Asegura que Persistent_nodes esté definido

func _ready() -> void:
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_to_server")
	
	device_ip_address.text = Network.ip_address
	
	if get_tree().network_peer != null:
		multiplayer_config_ui.hide()
		
		current_spawn_location_instance_number = 1
		for player in Persistent_nodes.get_children():
			if player.is_in_group("Player"):
				for spawn_location in $Spawn_locations.get_children():
					if int(spawn_location.name) == current_spawn_location_instance_number and current_player_for_spawn_location_number != player:
						player.rpc("update_position", spawn_location.global_position)
						player.rpc("enable")
						current_spawn_location_instance_number += 1
						current_player_for_spawn_location_number = player
	else:
		start_game.hide()

func _process(_delta: float) -> void:
	if get_tree().network_peer != null:
		if get_tree().get_network_connected_peers().size() >= 1 and get_tree().is_network_server():
			start_game.show()
		else:
			start_game.hide()

func _player_connected(id) -> void:
	print("Player " + str(id) + " has connected")
	instance_player(id)

func _player_disconnected(id) -> void:
	print("Player " + str(id) + " has disconnected")
	
	if Persistent_nodes.has_node(str(id)):
		var player = Persistent_nodes.get_node(str(id))
		if player.team == "red":
			team_counts["red"] -= 1
		elif player.team == "blue":
			team_counts["blue"] -= 1
		player.username_text_instance.queue_free()
		player.queue_free()
	
	# Reiniciar el índice de spawn si ya no hay jugadores activos
	if Persistent_nodes.get_children().size() == 0:
		current_spawn_location_instance_number = 1

func _on_Create_server_pressed():
	if username_text_edit.text != "":
		Network.current_player_username = username_text_edit.text
		multiplayer_config_ui.hide()
		Network.create_server()
		instance_player(get_tree().get_network_unique_id())

func _on_Join_server_pressed():
	if username_text_edit.text != "":
		multiplayer_config_ui.hide()
		username_text_edit.hide()
		Global.instance_node(load("res://Server_browser.tscn"), self)

func _connected_to_server() -> void:
	yield(get_tree().create_timer(0.1), "timeout")
	instance_player(get_tree().get_network_unique_id())

func instance_player(id) -> void:
	# Reinicia el contador de posiciones si es necesario
	if current_spawn_location_instance_number > $Spawn_locations.get_child_count():
		current_spawn_location_instance_number = 1

	var spawn_location = get_node("Spawn_locations/" + str(current_spawn_location_instance_number)).global_position
	var player_instance = Global.instance_node_at_location(player, Persistent_nodes, spawn_location)
	
	player_instance.name = str(id)
	player_instance.set_network_master(id)
	player_instance.username = username_text_edit.text
	player_instance.show()  # Asegura que el jugador esté visible al reaparecer
	
	# Si es el servidor, asignar equipo y sincronizar
	if get_tree().is_network_server():
		var new_team = "red" if team_counts["red"] <= team_counts["blue"] else "blue"
		team_counts[new_team] += 1
		
		yield(get_tree(), "idle_frame")
		
		# Sincronizar el equipo y el color con todos los clientes
		player_instance.rpc("sync_team_color", new_team)
	
	# Avanza al siguiente punto de aparición
	current_spawn_location_instance_number += 1

func _on_Start_game_pressed():
	rpc("switch_to_game")

sync func switch_to_game() -> void:
	# Asegurarse de que todos los jugadores tengan sus equipos antes de comenzar
	yield(get_tree().create_timer(0.2), "timeout")
	
	for child in Persistent_nodes.get_children():
		if child.is_in_group("Player"):
			child.update_shoot_mode(true)
			# Asegurarse de que el color se aplique correctamente
			if child.team != "":
				child.apply_team_color()
			else:
				print("Error: Jugador sin equipo asignado")
	
	# Cambiar a la escena del juego
	get_tree().change_scene("res://Game.tscn")


