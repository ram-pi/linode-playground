#!/usr/bin/env bash

set -euo pipefail

VENV="/opt/linode-moe/.venv"
VLLM="${VENV}/bin/vllm"
PYTHON="${VENV}/bin/python"

echo "=== vLLM version ==="
"${PYTHON}" -c "import vllm; print(vllm.__version__)"
echo

# --help in newer vLLM (0.8.x+) uses underscores internally even though CLI
# accepts both forms. Grep for both to avoid false negatives.

echo "=== Authoritative Python config check (EngineArgs) ==="
"${PYTHON}" - <<'PYEOF'
import sys
import dataclasses

WANT = ["tensor_parallel_size", "data_parallel_size", "enable_expert_parallel"]

# vllm 0.8+ moved args to EngineArgs; newer versions may reorganise further.
# Try every known import path so the check stays valid across releases.
_engine_args_cls = None
for _mod, _cls in [
    ("vllm.engine.arg_utils", "EngineArgs"),
    ("vllm.engine.arg_utils", "AsyncEngineArgs"),
    ("vllm.entrypoints.llm", "LLM"),           # last-resort fallback
]:
    try:
        import importlib
        m = importlib.import_module(_mod)
        _engine_args_cls = getattr(m, _cls, None)
        if _engine_args_cls is not None:
            print(f"Using {_mod}.{_cls} for introspection")
            break
    except Exception:
        pass

if _engine_args_cls is None:
    print("ERROR: could not import EngineArgs — cannot verify flags programmatically")
    sys.exit(1)

# Collect all field/attribute names from the class.
try:
    fields = {f.name for f in dataclasses.fields(_engine_args_cls)}
except TypeError:
    # Not a dataclass; fall back to inspecting __init__ params.
    import inspect
    fields = set(inspect.signature(_engine_args_cls.__init__).parameters)

all_ok = True
for name in WANT:
    if name in fields:
        print(f"OK : {name}")
    else:
        print(f"WARN: {name} not found in {_engine_args_cls.__name__}")
        all_ok = False

sys.exit(0 if all_ok else 1)
PYEOF
