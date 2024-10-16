# Setup subproject for development
[no-exit-message]
[no-cd]
setup-subproject:
    @if [ -f pyproject.toml ]; then just _setup-python-subproject; \
    elif [ -f package.json ]; then just _setup-node-subproject; \
    else echo >&2 "ERROR: Run this inside a subproject's directory." && exit 1; fi
