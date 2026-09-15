# Among Us Open

Juego social de deducción estilo "Among Us" en **Godot 4.4** (compatible 4.x) con **GDScript** y nodos nativos. Sin plugins, sin assets externos: todo el arte se genera por código (`_draw`, `Polygon2D`, `GradientTexture2D`, `CPUParticles2D`).

1 jugador humano + 7 NPCs en una nave con 6 salas (Cafetería, Eléctrica, Motores, Médica, Armería, Puente) conectadas por pasillos. Roles al azar: 1 impostor, 7 tripulantes (al humano le puede tocar cualquiera).

## Ejecutar

```bash
godot4 --path .            # jugar (abre el menú principal, botón JUGAR)
godot4 --headless --import # validar importación
godot4 --headless --quit   # validar salida limpia
godot4 --headless res://scenes/test_logic.tscn  # test de lógica + integración
```

El binario también puede llamarse `godot` según la instalación.

## Controles

| Tecla | Acción |
|---|---|
| WASD / Flechas | Moverse |
| E | Interactuar (hacer tarea, fingir, usar ducto, cerrar panel) |
| R | Reportar cadáver cercano |
| Q | Matar (solo impostor, cooldown 25 s) |
| Espacio | Reunión de emergencia (junto a la mesa central, 1 por partida) |
| Esc | Pausa |

## Sistemas

- **Visión limitada**: `CanvasModulate` oscuro + `PointLight2D` con sombras por personaje (el impostor ve más lejos).
- **Tareas** (3 minijuegos): cablear colores, código numérico de 5 dígitos, calibrar barra móvil. Barra de progreso global arriba + lista de pendientes.
- **Impostor**: cooldown de kill de 25 s, deja cadáver, 2 ductos para viajar, finge tareas.
- **Reuniones**: teleport a la mesa, 20 s de discusión, votación con botones; los NPC votan por sospecha (testigos de kills, cercanía a cadáveres) o aleatorio ponderado. Se muestra quién votó a quién y la expulsión.
- **IA NPC**: estados Deambular / IrATarea / HacerTarea / Huir / Reportar (+ Acechar / Fingir / ductos el impostor), navegación con `NavigationRegion2D` + `NavigationAgent2D`.
- **Fin**: tripulantes ganan con todas las tareas o expulsando al impostor; el impostor gana al empatar (1v1). Pantalla de victoria/derrota + reinicio.

## Estructura

```
project.godot
scenes/  main.tscn, player.tscn, npc.tscn, test_logic.tscn
scripts/ game_state.gd (autoload: roles/fase/resultado), main.gd, ship_builder.gd,
         player.gd, npc.gd, character_visual.gd, corpse.gd, vent.gd,
         task_station.gd, task_manager.gd, meeting_manager.gd, logic_test.gd,
         hud.gd, main_menu.gd, task_ui.gd, game_over.gd, pause_menu.gd, space_bg.gd
ui/      hud.tscn, main_menu.tscn, task_ui.tscn, meeting_ui.tscn,
         game_over.tscn, pause_menu.tscn
```
