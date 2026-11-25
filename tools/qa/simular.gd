extends SceneTree
## Simulación de balance: el bot (tools/qa/bot.gd) juega muchas batallas por configuración.
##   godot --headless --path . -s tools/qa/simular.gd                  (bot razonable, cada dificultad)
##   godot --headless --path . -s tools/qa/simular.gd -- --azar        (además, bot al azar)
##   godot --headless --path . -s tools/qa/simular.gd -- --detalle     (bajas y cartas usadas)
##   godot --headless --path . -s tools/qa/simular.gd -- --con=italiano (solo donde juega ese bando)
##   godot --headless --path . -s tools/qa/simular.gd -- --mapa=bosque (un mapa de campaña)
##   godot --headless --path . -s tools/qa/simular.gd -- --campana     (cada batalla de cada campaña,
##        con una medalla por batalla ganada antes para todos los gatos: el caso optimista)
## Imprime % de victorias, duración y bajas por bando y dificultad.

const Combate := preload("res://scripts/combate.gd")
const PartidaScript := preload("res://scripts/partida.gd")
const Bot := preload("res://tools/qa/bot.gd")

const BATALLAS := 100
const TURNOS_MAX := 30
var ruta_mapa: String = PartidaScript.MAPA_LIBRE
## Todos los enfrentamientos posibles (jugador, rival) entre los batallones de los datos.
static func enfrentamientos() -> Array:
	var ids: Array = PartidaScript.batallones().keys()
	var res: Array = []
	for j in ids:
		for r in ids:
			if j != r:
				res.append([j, r])
	return res


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mapa_arg: Array = Array(args).filter(func(x): return x.begins_with("--mapa="))
	if not mapa_arg.is_empty():
		ruta_mapa = "res://data/mapas/%s.json" % mapa_arg[0].substr(7)
	var tipos_bot := ["razonable"] + (["azar"] if "--azar" in args else [])
	if "--campana" in args:
		_simular_campanas()
		quit()
		return
	print("bot          dificultad  bando        gana  pierde  turnos  bajas propias/rivales")
	for tipo in tipos_bot:
		for dif in PartidaScript.DIFICULTADES:
			for b in enfrentamientos():
				# --solo=britanico simula solo cuando ese bando es el jugador.
				var solo: Array = Array(args).filter(func(x): return x.begins_with("--solo="))
				if not solo.is_empty() and solo[0].substr(7) != b[0]:
					continue
				var dif_sola: Array = Array(args).filter(func(x): return x.begins_with("--dif="))
				if not dif_sola.is_empty() and dif_sola[0].substr(6) != dif:
					continue
				# --con=italiano: solo los enfrentamientos donde está ese bando (de cualquier lado).
				var con: Array = Array(args).filter(func(x): return x.begins_with("--con="))
				if not con.is_empty() and not con[0].substr(6) in b:
					continue
				_simular(b[0], b[1], dif, tipo == "azar", "--detalle" in args)
	quit()


func _simular_campanas() -> void:
	print("batallón       batalla  mapa      dificultad  rival            gana (sin medallas / con)")
	for jugador in PartidaScript.RIVALES_CAMPANA:
		for n in PartidaScript.CAMPANA.size():
			var paso: Dictionary = PartidaScript.CAMPANA[n]
			var rival: String = PartidaScript.RIVALES_CAMPANA[jugador][n]
			var medallas := {}
			for u in PartidaScript.batallones()[jugador]["unidades"]:
				medallas[u["id"]] = n
			var sin := _ganadas(jugador, rival, paso["dificultad"], paso["mapa"], {})
			var con := _ganadas(jugador, rival, paso["dificultad"], paso["mapa"], medallas)
			print("%-14s %d        %-9s %-11s %-16s %3d%% / %3d%%" % [jugador, n + 1,
				paso["mapa"].get_file().get_basename(), paso["dificultad"], rival, sin, con])


func _ganadas(jugador: String, rival: String, dif: String, mapa: String, medallas: Dictionary) -> int:
	var bot := Bot.new()
	bot.rng.seed = 1234
	var ganadas := 0
	for semilla in BATALLAS:
		var c := Combate.new()
		PartidaScript.iniciar_combate(c, jugador, rival, semilla, false, dif, mapa, medallas)
		while c.estado == "jugando" and c.turno <= TURNOS_MAX:
			bot.jugar_turno(c)
		if c.estado == "victoria":
			ganadas += 1
	return ganadas * 100 / BATALLAS


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
		PartidaScript.iniciar_combate(c, jugador, rival, semilla, false, dif, ruta_mapa)
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
	print("%-12s %-9s %-14s vs %-14s %3d%%  %4d%%  %6.1f  %.1f / %.1f" % [
		"al azar" if azar else "razonable", dif, jugador, rival,
		resultados["victoria"] * 100 / BATALLAS, resultados["derrota"] * 100 / BATALLAS,
		float(turnos_total) / BATALLAS, float(bajas_propias) / BATALLAS, float(bajas_rivales) / BATALLAS])
	if detalle:
		print("    derribados: %s" % str(muertes))
		print("    cartas: %s" % str(bot.cartas_jugadas))
