extends SceneTree
## ¿Cuánto vale cada carta? Para cada carta del mazo, el bot juega N batallas en Veterano
## sin ninguna copia de ella y se compara con el mazo completo. Si quitarla no cambia
## las victorias ni las bajas, la carta no aporta.
##   godot --headless --path . -s tools/qa/cartas.gd

const Combate := preload("res://scripts/combate.gd")
const PartidaScript := preload("res://scripts/partida.gd")
const Bot := preload("res://tools/qa/bot.gd")

const BATALLAS := 100
const DIFICULTAD := "veterano"


func _initialize() -> void:
	for bandos in [["britanico", "sovietico"], ["sovietico", "britanico"]]:
		var base := _simular(bandos[0], bandos[1], "")
		print("\n== %s (%s) ==  mazo completo: gana %d%%, bajas propias %.2f, turnos %.1f" % [
			bandos[0], DIFICULTAD, base["gana"], base["bajas"], base["turnos"]])
		print("    uso por batalla: %s" % str(base["uso"]))
		var ids: Array = []
		var c := Combate.new()
		PartidaScript.iniciar_combate(c, bandos[0], bandos[1], 1, false, DIFICULTAD)
		for i in c.aliados.size():
			for id in c.cartas_de(i):
				if not ids.has(id):
					ids.append(id)
		for id in ids:
			if id == "girar":
				continue  # Girar lo tienen todos siempre; no se puede quitar desde los datos
			var r := _simular(bandos[0], bandos[1], id)
			print("    sin %-16s gana %3d%% (%+d)   bajas %.2f (%+.2f)" % [id, r["gana"], r["gana"] - base["gana"],
				r["bajas"], r["bajas"] - base["bajas"]])
	quit()


func _simular(jugador: String, rival: String, quitar: String) -> Dictionary:
	var gana := 0
	var bajas := 0
	var turnos := 0
	var bot := Bot.new()
	for semilla in BATALLAS:
		var c := Combate.new()
		PartidaScript.iniciar_combate(c, jugador, rival, semilla, false, DIFICULTAD)
		if quitar != "":
			# Se le quita esa carta a todos los gatos que la tengan.
			for u in c.aliados:
				u["habilidades"] = u["habilidades"].filter(func(x): return x != quitar)
		while c.estado == "jugando" and c.turno <= 30:
			bot.jugar_turno(c)
		if c.estado == "victoria":
			gana += 1
		turnos += c.turno
		for u in c.aliados:
			if not c.vivo(u):
				bajas += 1
	var uso := {}
	for id in bot.cartas_jugadas:
		uso[id] = snappedf(float(bot.cartas_jugadas[id]) / BATALLAS, 0.1)
	return {"gana": gana * 100 / BATALLAS, "bajas": float(bajas) / BATALLAS,
		"turnos": float(turnos) / BATALLAS, "uso": uso}
