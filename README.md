# just-kit

A kit for managing reusable tools and [just](https://github.com/casey/just) recipes
to ease your daily workflows and maintenance tasks.

Designed as an import manager for your project's `justfile`,
this kit provides a convenient `*.just` file selection tool
establishing a flexible way to share useful helper utilities
with the community and your colleagues.

## Enhance your project

From within your project root, run the `setup.sh` of this repository.

If you already have a `justfile`, it gets extended, otherwise it will be created for you.

The setup script will enable and run the `pick` recipe,
which presents you with a pre-filtered list of `*.just` files to pick from.

Additionally, a `just-bash` symlink is created
that you may source using `source just-bash`
to profit from auto-completion for [Typer](https://github.com/fastapi/typer) scripts.

For convenience, it also runs `nvm use` for you.

### Re-configure (select just files to import)

Run `just pick` from within your project tree.
This is a convenience tool to manage the imports of your project's `justfile`.

When there are duplicate recipes, you are asked to choose
which `*.just` file containing the conflicting recipe(s) should override the other,
defining the import order.
Your selection is remembered through a comment next to the import statement.

## Adding features

All `*.just` files located in parent directories and `.just` directories within them
are considered candidates for the `*.just` file selection.

To add `*.just` files from other locations using `just pick`,
add or extend `EXTRA_JUST_ROOTS` variable with the respective paths
(either in the environment or in the `.env` file in your project root).
Multiple paths are separated with `:`.

Run `just pick` to select them.

### Hiding just files

A `_check-justile-relevance` recipe may be added to a `*.just` file
to be able to hide it from the list if not relevant for your current project
(non-zero exit code will hide it).

Example recipe to hide a `*.just` file when there is no `poetry` tool installed:

```just
_check-justile-relevance:
    @command -v poetry
```

Example recipe to hide a `*.just` file when there is no `.env` file in your project's root:

```just
[no-cd]
_check-justile-relevance:
    @[ -f .env ]
```

## Running python scripts

You can forward a command to a self-contained python app powered by [uv](https://github.com/astral-sh/uv):

```just
[no-cd]
my-python-app *ARGS:
    @"{{justfile_directory()}}/scripts/my-python-app.py" "$@"
```

The python script needs to start with something like this:

```python
#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "typer",
# ]
# [tool.uv]
# exclude-newer = "2025-07-11T00:00:00Z"
# ///
```

If you do not like those comments, you can instead provide the required configuration
by running `uv` directly:

```just
[no-cd]
my-python-app *ARGS:
    @uv run --no-project --python 3.12 --with typer "{{justfile_directory()}}/scripts/my-python-app.py" "$@"
```

See <https://docs.astral.sh/uv/guides/scripts/> for more information.

### Auto-completion with Typer

Running `source just-bash` will enable auto-completion
for [Typer](https://github.com/fastapi/typer) apps
when their recipe has the special argument `*TYPER_ARGS`.

Example for a just recipe that will have auto-completion:

```just
[no-cd]
my-typer-app *TYPER_ARGS:
    @"{{justfile_directory()}}/scripts/my-typer-app.py" "$@"
```

Example for a just recipe that will have auto-completions using a separate completer:

```just
[no-cd]
[script]
my-app *TYPER_ARGS:
    "{{justfile_directory()}}/scripts/my-non-typer-app.sh" "$@"
    exit 0
    "{{justfile_directory()}}/scripts/my-typer-app.py" # last command is used as completer
```

See <https://typer.tiangolo.com/#example> for a minimal example.

## Running python scripts using wrapper scripts (legacy)

You can forward a command to a python app.

```just
[no-cd]
my-python-app *ARGS:
    @"{{justfile_directory()}}/scripts/my-python-app-wrapper-script.sh" "$@"
```

Example for a wrapper script that uses `poetry` from within your project:
`scripts/my-python-app-wrapper-script.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

GIT_ROOT="$(git rev-parse --show-toplevel)"
PARENT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"

PYTHONPATH="$PARENT_DIR" poetry run -P "${GIT_ROOT}" python "${PARENT_DIR}/my-app.py" "$@"
```

Example for a wrapper script using `uv` from within your project:
`scripts/my-python-app-wrapper-script.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

PARENT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"

uv run --project "${PARENT_DIR}" "${PARENT_DIR}/my-app.py" "$@"
```

## Development

### Setup for development

```bash
uv run pre-commit install
```
