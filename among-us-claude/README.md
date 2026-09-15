# Impostor en Órbita

Juego tipo *Among Us* hecho desde cero en **Godot 4.4 + GDScript**, sin assets externos:
todo el arte (personajes, nave, luces, partículas) se genera por código.

## Ejecutar

```bash
godot4 --path . ui/MainMenu.tscn    # o simplemente: godot4 --path .
```
También puedes abrir `project.godot` desde el editor de Godot y pulsar F5.

### Validación headless
```bash
godot4 --headless --import
godot4 --headless --quit
tools/check.sh            # import + arranque + tests, con todos los warnings de GDScript tratados como error
```
Los tests (`tests/TestRunner.tscn`) prueban roles, votación, tareas, condiciones de victoria,
los 3 minijuegos, la navegación a las 6 salas, que la UI quede dentro de pantalla y simulan
una partida completa con la IA (asesinato, reporte, reunión, votación y final).

## Controles

| Tecla | Acción |
|---|---|
| WASD / Flechas | Moverse |
| E | Usar (tarea / ducto si eres impostor) |
| R | Reportar cadáver cercano |
| Q | Matar (solo impostor, cooldown 25 s) |
| Espacio | Reunión de emergencia (junto a la mesa de la Cafetería, 1 por partida) |
| Esc | Pausa / cerrar minijuego |
| Mouse | Minijuegos y votación |

## Reglas
- 8 jugadores (tú + 7 NPCs), 1 impostor al azar: puedes ser tú.
- Tripulación gana completando todas las tareas o expulsando al impostor.
- El impostor gana cuando queda 1 contra 1.
- Minijuegos: **cables** (arrastra cada color a su par), **código** (teclea el número mostrado),
  **calibrar** (detén la barra en la zona verde 3 veces).
- Reuniones: 20 s de discusión (los NPCs hablan), 15 s de votación, resultados con quién votó a quién y expulsión.

## Estructura
```
project.godot
scenes/Game.tscn          escena de partida (nodos + scripts)
scripts/GameState.gd      autoload: roles, fase, tareas, resultado, input map
scripts/Game.gd           orquestador: spawn, acciones, asesinatos, reuniones, fin
scripts/ShipMap.gd        salas, pasillos, paredes, oclusores y navegación (bake por código)
scripts/Character.gd      base de personaje (dibujo, nombre, luz)
scripts/Player.gd         control del jugador
scripts/NPC.gd            IA: máquina de estados + NavigationAgent2D
scripts/MeetingManager.gd flujo de reunión y votos
scripts/VoteLogic.gd      heurística de voto y conteo (pura, testeable)
scripts/CharacterSprite.gd, Body.gd, TaskStation.gd, Vent.gd, ShakeCamera.gd, Effects.gd
ui/                       menú, HUD, minijuegos, reunión, pausa, transición, pantalla final
tests/                    tests headless
tools/check.sh            validación completa
```
