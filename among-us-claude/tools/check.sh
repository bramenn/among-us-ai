#!/usr/bin/env bash
# Valida el proyecto: import, arranque y tests headless, con todos los warnings de GDScript
# convertidos en error vía override.cfg (el test carga todas las escenas y scripts).
# Uso: tools/check.sh [binario_godot]   (por defecto godot4, o godot si no existe)
set -u
cd "$(dirname "$0")/.."
GODOT="${1:-$(command -v godot4 || command -v godot)}"
WARNS="unassigned_variable unassigned_variable_op_assign unused_variable unused_local_constant unused_private_class_variable unused_parameter unused_signal shadowed_variable shadowed_variable_base_class shadowed_global_identifier unreachable_code unreachable_pattern standalone_expression standalone_ternary incompatible_ternary unsafe_void_return static_called_on_instance redundant_await assert_always_true assert_always_false integer_division narrowing_conversion int_as_enum_without_cast int_as_enum_without_match enum_variable_without_default empty_file deprecated_keyword confusable_identifier confusable_local_declaration confusable_local_usage confusable_capture_reassignment inference_on_variant"
{ echo "[debug]"; for w in $WARNS; do echo "gdscript/warnings/$w=2"; done; } > override.cfg
trap 'rm -f override.cfg' EXIT
fail=0
out=$("$GODOT" --headless --import 2>&1); echo "$out" | grep -E "ERROR|WARNING" && fail=1
out=$("$GODOT" --headless --quit 2>&1); echo "$out" | grep -E "ERROR|WARNING" && fail=1
timeout 300 "$GODOT" --headless --fixed-fps 60 res://tests/TestRunner.tscn 2>&1 | tee /tmp/au_test.log | grep -vE "^Godot Engine|^$"
[ "${PIPESTATUS[0]}" -ne 0 ] && fail=1
grep -qE "SCRIPT ERROR|^ERROR|WARNING" /tmp/au_test.log && fail=1
[ $fail -eq 0 ] && echo "CHECK OK" || echo "CHECK FAILED"
exit $fail
