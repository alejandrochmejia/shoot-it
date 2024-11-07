extends Sprite

var velocity = Vector2(1, 0)
var player_rotation

export(int) var speed = 1400
export(int) var damage = 25

puppet var puppet_position setget puppet_position_set
puppet var puppet_velocity = Vector2(0, 0)
puppet var puppet_rotation = 0

onready var initial_position = global_position

var player_owner = 0
var team = ""  # Nuevo atributo para el equipo

func _ready() -> void:
	visible = false
	yield(get_tree(), "idle_frame")
	
	if get_tree().has_network_peer():
		if is_network_master():
			velocity = velocity.rotated(player_rotation)
			rotation = player_rotation
			rset("puppet_velocity", velocity)
			rset("puppet_rotation", rotation)
			rset("puppet_position", global_position)
	
	visible = true
	
	# Conectar la señal de colisión del Hitbox
	$Hitbox.connect("body_entered", self, "_on_Hitbox_body_entered")  # Conectar señal de colisión

func _process(delta: float) -> void:
	if get_tree().has_network_peer():
		if is_network_master():
			global_position += velocity * speed * delta
		else:
			rotation = puppet_rotation
			global_position += puppet_velocity * speed * delta

func puppet_position_set(new_value) -> void:
	puppet_position = new_value
	global_position = puppet_position

sync func destroy() -> void:
	queue_free()

func _on_Destroy_timer_timeout():
	if get_tree().has_network_peer():
		if get_tree().is_network_server():
			rpc("destroy")

# Nueva función para aplicar daño
sync func apply_damage(damage_amount, attacker_team):
	if team != attacker_team:  # Verifica si el atacante es de un equipo diferente
		# Aplicar el daño aquí (puedes agregar lógica para reducir la salud del jugador)
		print("Recibido daño: " + str(damage_amount))
		# Aquí puedes agregar la lógica para reducir la vida del jugador
	else:
		print("No se puede dañar a un compañero de equipo.")

# Función para manejar colisiones
func _on_Hitbox_body_entered(body):
	if body.is_in_group("estructuras"):  # Asegúrate de que las estructuras estén en el grupo "estructuras"
		destroy()  # Destruir la bala al chocar con una estructura

# Manejar colisión con el TileMap
func _on_Hitbox_area_entered(area):
	if area.is_in_group("tiles"):  # Cambia "tiles" por el nombre del grupo que hayas definido
		destroy()  # Destruir la bala al chocar con un tile


