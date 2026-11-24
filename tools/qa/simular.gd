extends SceneTree
## Simulación de balance: el bot (tools/qa/bot.gd) juega muchas batallas por configuración.
##   godot --headless --path . -s tools/qa/simular.gd            (bot razonable)
##   godot --headless --path . -s tools/qa/simular.gd -- --azar  (bot al azar, línea base)
## Imprime % de victorias, duración, bajas y cartas más usadas.

const Combate := preload("res://scripts/combate.gd")
const PartidaScript := preload("res://scripts/partida.gd")
const Bot := preload("res://tools/qa/bot.gd")

const BATALLAS := 150
const TURNOS_MAX := 30
const CONFIGURACIONES := [
	["britanico", "sovietico", false],
	["britanico", "sovietico", true],
	["sovietico", "britanico", false],
	["sovietico", "britanico", true],
]


func _initialize() -> void:
	var solo_azar := "--azar" in OS.get_cmdline_user_args()
	for conf in CONFIGURACIONES:
		if not solo_azar:
			_simular(conf[0], conf[1], conf[2], false)
		elif not conf[2]:
			_simular(conf[0], conf[1], false, true)
	quit()


func _simular(jugador: String, rival: String, con_michi: bool, azar: bool) -> void:
	var resultados := {"victoria": 0, "derrota": 0, "empate": 0}
	var turnos_total := 0
	var bajas_propias := 0
	var bajas_rivales := 0
	var muertes := {}  # nombre -> veces derribado
	var ordenes := 0
	var cumplidas := 0
	var bot := Bot.new()
	bot.aleatorio = azar
	bot.rng.seed = 1234
	for semilla in BATALLAS:
		var c := Combate.new()
		PartidaScript.iniciar_combate(c, jugador, rival, semilla, con_michi)
		while c.estado == "jugando" and c.turno <= TURNOS_MAX:
			var orden_turno: int = c.orden
			bot.jugar_turno(c)
			if orden_turno >= 0:
				ordenes += 1
				# terminar_turno ya revisó la orden: si hubo premio, la energía subió.
				if c.energia > Combate.ENERGIA_POR_TURNO or (c.estado != "jugando" and c.orden_cumplida):
					cumplidas += 1
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
				muertes[e["nombre"] + " (rival)"] = muertes.get(e["nombre"] + " (rival)", 0) + 1
	print("\n== %s contra %s %s%s ==" % [jugador, rival, "(con Michi)" if con_michi else "", " [bot al azar]" if azar else ""])
	print("victorias %d%%   derrotas %d%%   empates %d%%   turnos promedio %.1f" % [
		resultados["victoria"] * 100 / BATALLAS, resultados["derrota"] * 100 / BATALLAS,
		resultados["empate"] * 100 / BATALLAS, float(turnos_total) / BATALLAS])
	print("bajas por batalla: propias %.2f   rivales %.2f" % [float(bajas_propias) / BATALLAS, float(bajas_rivales) / BATALLAS])
	var lista := muertes.keys()
	lista.sort_custom(func(a, b): return muertes[a] > muertes[b])
	print("derribados (veces/150): " + ", ".join(lista.map(func(n): return "%s %d" % [n, muertes[n]])))
	var usadas := bot.cartas_jugadas.keys()
	usadas.sort_custom(func(a, b): return bot.cartas_jugadas[a] > bot.cartas_jugadas[b])
	print("cartas jugadas: " + ", ".join(usadas.map(func(n): return "%s %d" % [n, bot.cartas_jugadas[n]])))
	if con_michi:
		print("órdenes de Michi: %d, cumplidas ~%d%%" % [ordenes, cumplidas * 100 / maxi(ordenes, 1)])
