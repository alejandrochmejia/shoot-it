extends CanvasLayer

onready var win_timer = $Control/Winner/Win_timer
onready var winner = $Control/Winner

func _ready() -> void:
	winner.hide()
	Global.ui = self # Registrar la UI en Global

func _process(_delta: float) -> void:
	if get_tree().has_network_peer():
		var red_team_alive = false
		var blue_team_alive = false
		
		# Verificar si hay jugadores vivos en cada equipo
		for player in Global.alive_players:
			if player.team == "red":
				red_team_alive = true
			elif player.team == "blue":
				blue_team_alive = true
				
			# Si ambos equipos tienen jugadores vivos, no hay necesidad de seguir verificando
			if red_team_alive and blue_team_alive:
				break
		
		# Si un equipo ha sido eliminado
		if !red_team_alive or !blue_team_alive:
			# Mostrar mensaje de victoria solo para el equipo ganador
			if Global.player_master:
				var winning_team = "blue" if !red_team_alive else "red"
				if Global.player_master.team == winning_team:
					winner.show()
			
			# Iniciar el temporizador si no está corriendo
			if win_timer.time_left <= 0:
				win_timer.start()
