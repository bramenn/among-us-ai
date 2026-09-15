# Among Us en Godot: dos versiones

Ejercicio para un video: el mismo reto (un juego tipo *Among Us* en **Godot 4.4 + GDScript**, sin assets externos) resuelto por dos agentes de IA distintos.

| Carpeta | Juego | Hecho con |
|---|---|---|
| [`among-us-open/`](among-us-open/) | Among Us Open | OpenCode |
| [`among-us-claude/`](among-us-claude/) | Impostor en Órbita | Claude Code |

Cada carpeta es un proyecto Godot independiente con su propio README (controles, reglas y estructura).

## Ejecutar

Necesitas [Godot 4.4](https://godotengine.org/download) o superior.

```bash
godot4 --path among-us-open
godot4 --path among-us-claude
```

O abre el `project.godot` de cualquiera de las dos carpetas en el editor y pulsa F5.

## Tests

```bash
godot4 --headless --path among-us-open res://scenes/test_logic.tscn
among-us-claude/tools/check.sh
```
