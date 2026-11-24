extends SceneTree
## Simulación de balance: el bot (tools/qa/bot.gd) juega muchas batallas por configuración.
##   godot --headless --path . -s tools/qa/simular.gd                  (bot razonable, cada dificultad)
##   godot --headless --path . -s tools/qa/simular.gd -- --azar        (además, bot al azar)
##   godot --headless --path . -s tools/qa/simular.gd -- --detalle     (bajas y cartas usadas)
## Imprime % de victorias, duración y bajas por bando y dificultad.

const Combate := preload("res://scripts/combate.gd")
const PartidaScript := preload("res://scripts/partida.gd")
const Bot := preload("res://tools/qa/bot.gd")

const BATALLAS := 100
const TURNOS_MAX := 30
const BANDOS := [["britanico", "sovietico"], ["sovietico", "britanico"]]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var tipos_bot := ["razonable"] + (["azar"] if "--azar" in args else [])
	print("bot          dificultad  bando        gana  pierde  turnos  bajas propias/rivales")
	for tipo in tipos_bot:
		for dif in PartidaScript.DIFICULTADES:
			for b in BANDOS:
				_simular(b[0], b[1], dif, tipo == "azar", "--detalle" in args)
	quit()


func _simular(jugador: String, rival: String, dif: String, azar: bool, detalle: bool) -> void:
	var resultados := {"victoria": 0, "derrota": 0, "empate": 0}
	var turnos_total := 0
	var bajas_propias := 0
	var bajas_rivales := 0
	var muertes := {}
	var bot := Bot.new()
	bot.aleatorio = azar
	bot.rng.seed = 1234
	for semilla in BATALLAS:
		var c := Combate.new()
		PartidaScript.iniciar_combate(c, jugador, rival, semilla, false, dif)
		while c.estado == "jugando" and c.turno <= TURNOS_MAX:
			bot.jugar_turno(c)
		var r: String = c.estado if c.estado != "jugando" else "empate"
		resultados[r] += 1
		turnos_total += c.turno
		for u in c.aliados:
			if not c.vivo(u):
				bajas_propias += 1
				muertes[u["nombre"]] = muertes.get(u["nombre"], 0) + 1
		for e in c.enemigos:
			if not c.vivo(e):
				bajas_rivales += 1
	print("%-12s %-11s %-12s %3d%%  %4d%%  %6.1f  %.1f / %.1f" % [
		"al azar" if azar else "razonable", dif, jugador,
		resultados["victoria"] * 100 / BATALLAS, resultados["derrota"] * 100 / BATALLAS,
		float(turnos_total) / BATALLAS, float(bajas_propias) / BATALLAS, float(bajas_rivales) / BATALLAS])
	if detalle:
		print("    derribados: %s" % str(muertes))
		print("    cartas: %s" % str(bot.cartas_jugadas))
