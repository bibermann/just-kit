[no-exit-message]
_setup-python-subproject RECREATE="true":
    echo >&2 "ERROR: No python tasks added to justfile."
    exit 1

[no-exit-message]
_setup-node-subproject RECREATE="true":
    echo >&2 "ERROR: No node tasks added to justfile."
    exit 1

_check-env-file:

_ensure-pre-commit:
