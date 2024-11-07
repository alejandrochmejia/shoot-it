extends KinematicBody2D

const speed = 400

var is_hit = false

# Variables de equipo y color
var team = "" setget set_team
var team_color = Color.white
puppet var puppet_team = "" setget puppet_team_set

var hp = 100 setget set_hp
var velocity = Vector2(0, 0)
var can_shoot = true
var is_reloading = false

var player_bullet = load("res://Player_bullet.tscn")
var username_text = load("res://Username_text.tscn")

var username setget username_set
var username_text_instance = null

puppet var puppet_hp = 100 setget puppet_hp_set
puppet var puppet_position = Vector2(0, 0) setget puppet_position_set
puppet var puppet_velocity = Vector2()
puppet var puppet_rotation = 0
puppet var puppet_username = "" setget puppet_username_set

onready var tween = $Tween
onready var sprite = $Sprite
onready var reload_timer = $Reload_timer
onready var shoot_point = $Shoot_point
onready var hit_timer = $Hit_timer

func _ready():
	get_tree().connect("network_peer_connected", self, "_network_peer_connected")
	
	username_text_instance = Global.instance_node_at_location(username_text, Persistent_nodes, global_position)
	username_text_instance.player_following = self
	
	update_shoot_mode(false)
	Global.alive_players.append(self)
	
	# Aplicar color inicial
	if team != "":
		apply_team_color()
	
	yield(get_tree(), "idle_frame")
	if get_tree().has_network_peer():
		if is_network_master():
			Global.player_master = self
			
	if is_network_master():
		rpc("request_team_color")

func _process(delta: float) -> void:
	if username_text_instance != null:
		username_text_instance.name = "username" + name
	
	if get_tree().has_network_peer():
		if is_network_master() and visible:
			var x_input = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
			var y_input = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
			
			velocity = Vector2(x_input, y_input).normalized()
			
			move_and_slide(velocity * speed)
			
			look_at(get_global_mouse_position())
			
			if Input.is_action_pressed("click") and can_shoot and not is_reloading:
				rpc("instance_bullet", get_tree().get_network_unique_id())
				is_reloading = true
				reload_timer.start()
		else:
			rotation = lerp_angle(rotation, puppet_rotation, delta * 8)
			
			if not tween.is_active():
				move_and_slide(puppet_velocity * speed)
	
	if hp <= 0:
		if username_text_instance != null:
			username_text_instance.visible = false
		
		if get_tree().has_network_peer():
			if get_tree().is_network_server():
				rpc("destroy")

remote func request_team_color():
	if get_tree().is_network_server():
		var requesting_id = get_tree().get_rpc_sender_id()
		rpc_id(requesting_id, "sync_team_color", team)

func set_team(new_team: String) -> void:
	team = new_team
	apply_team_color() # Aplicar color inmediatamente
	
	if get_tree().has_network_peer():
		if is_network_master():
			rpc("sync_team_color", new_team)

sync func sync_team_color(new_team: String) -> void:
	team = new_team
	apply_team_color()
	if get_tree().is_network_server():
		rset("puppet_team", team)

func puppet_team_set(new_team: String) -> void:
	team = new_team
	apply_team_color()

func apply_team_color() -> void:
	match team:
		"red":
			team_color = Color(1, 0.2, 0.2)
		"blue":
			team_color = Color(0.2, 0.6, 1)
		_:
			team_color = Color.white
	
	if has_node("Sprite"):
		$Sprite.self_modulate = team_color
	modulate = Color(1, 1, 1, 1)

func lerp_angle(from, to, weight):
	return from + short_angle_dist(from, to) * weight

func short_angle_dist(from, to):
	var max_angle = PI * 2
	var difference = fmod(to - from, max_angle)
	return fmod(2 * difference, max_angle) - difference

func puppet_position_set(new_value) -> void:
	puppet_position = new_value
	
	tween.interpolate_property(self, "global_position", global_position, puppet_position, 0.1)
	tween.start()

func set_hp(new_value):
	hp = new_value
	
	if get_tree().has_network_peer():
		if is_network_master():
			rset("puppet_hp", hp)

func puppet_hp_set(new_value):
	puppet_hp = new_value
	
	if get_tree().has_network_peer():
		if not is_network_master():
			hp = puppet_hp

func username_set(new_value) -> void:
	username = new_value
	
	if get_tree().has_network_peer():
		if is_network_master() and username_text_instance != null:
			username_text_instance.text = username
			rset("puppet_username", username)

func puppet_username_set(new_value) -> void:
	puppet_username = new_value
	
	if get_tree().has_network_peer():
		if not is_network_master() and username_text_instance != null:
			username_text_instance.text = puppet_username

func _network_peer_connected(id) -> void:
	if is_network_master():
		rset_id(id, "puppet_username", username)
		rset_id(id, "puppet_team", team)
		rpc_id(id, "sync_team_color", team)

func _on_Network_tick_rate_timeout():
	if get_tree().has_network_peer():
		if is_network_master():
			rset_unreliable("puppet_position", global_position)
			rset_unreliable("puppet_velocity", velocity)
			rset_unreliable("puppet_rotation", rotation)

sync func instance_bullet(id):
	var player_bullet_instance = Global.instance_node_at_location(player_bullet, Persistent_nodes, shoot_point.global_position)
	player_bullet_instance.name = "Bullet" + name + str(Network.networked_object_name_index)
	player_bullet_instance.set_network_master(id)
	player_bullet_instance.player_rotation = rotation
	player_bullet_instance.player_owner = id
	Network.networked_object_name_index += 1

sync func update_position(pos):
	global_position = pos
	puppet_position = pos

func update_shoot_mode(shoot_mode):
	if not shoot_mode:
		sprite.set_region_rect(Rect2(0, 1500, 256, 250))
	else:
		sprite.set_region_rect(Rect2(512, 1500, 256, 250))
	
	can_shoot = shoot_mode

func _on_Reload_timer_timeout():
	is_reloading = false

sync func hit_by_damager(damage):
	hp -= damage
	modulate = Color(2, 2, 2, 1)
	hit_timer.start()

func _on_Hit_timer_timeout():
	modulate = Color(1, 1, 1, 1)

func _on_Hitbox_area_entered(area):
	if get_tree().is_network_server():
		if area.is_in_group("Player_damager"):
			var attacker = Global.get_player_by_id(area.get_parent().player_owner)
			if attacker != null:
				if attacker.team != team:
					rpc("hit_by_damager", area.get_parent().damage)
					area.get_parent().rpc("destroy")

func enable() -> void:
	hp = 100
	can_shoot = false
	update_shoot_mode(false)
	username_text_instance.visible = true
	visible = true
	$CollisionShape2D.disabled = false
	$Hitbox/CollisionShape2D.disabled = false
	
	# Asegurarse de que el color se aplique al habilitar
	apply_team_color()
	
	if get_tree().has_network_peer():
		if is_network_master():
			Global.player_master = self
	
	if not Global.alive_players.has(self):
		Global.alive_players.append(self)

sync func destroy() -> void:
	username_text_instance.visible = false
	visible = false
	$CollisionShape2D.disabled = true
	$Hitbox/CollisionShape2D.disabled = true
	Global.alive_players.erase(self)  # Eliminar de la lista de jugadores vivos

	if get_tree().has_network_peer():
		if is_network_master():
			Global.player_master = null

	Global.check_team_elimination(team)

func _exit_tree() -> void:
	Global.alive_players.erase(self)
	if get_tree().has_network_peer():
		if is_network_master():
			Global.player_master = null

# Cambiar a "sync" para que todos los jugadores en la red reciban la llamada
sync func reset_player():
	hp = 100  # Restablecer la salud
	visible = true  # Hacer visible al jugador
	$CollisionShape2D.disabled = false  # Habilitar colisiones
	$Hitbox/CollisionShape2D.disabled = false  # Habilitar hitbox
	username_text_instance.visible = true  # Hacer visible el texto del nombre
	update_shoot_mode(true)  # Permitir disparar nuevamente
	apply_team_color()  # Aplicar el color del equipo
	
	# Reaparecer en la posición de spawn del equipo
	global_position = Global.get_spawn_position(team)  # Llama con el equipo como argumento
	
	# Sincronización en red
	if get_tree().has_network_peer():
		if is_network_master():
			rset("puppet_hp", hp)
			rset("puppet_position", global_position)
	
	# Agregar de nuevo a la lista de jugadores vivos si no está en ella
	if not Global.alive_players.has(self):
		Global.alive_players.append(self)

