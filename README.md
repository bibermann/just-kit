# just-kit

A kit for managing reusable tools and [just](https://github.com/casey/just) recipes
to ease your daily workflows and maintenance tasks.

Designed as an import manager for your project's `justfile`,
this kit provides a convenient `*.just` file selection tool
establishing a flexible way to share useful helper utilities
with the community and your colleagues.

## Prerequisites

- Bash
- Git
- [jq](https://jqlang.org/download/)
- [just](https://just.systems/man/en/packages.html)

## Installation

Clone <https://github.com/bibermann/just-kit> to a proper location, e.g.:

```bash
git clone https://github.com/bibermann/just-kit ~/.just/kit
```

## Enhance your project

From within your project root, run the `setup` script of this repository, e.g.:

```bash
cd /path/to/your/project
~/.just/kit/setup
```

The `setup` script will import and run the `pick` recipe in your `justfile`
(eventually creating it). It will also create a `just-bash` symlink.

If there is a `default-just-files.txt` file within your project,
it will also try to find and import the respective files for you
to already have them pre-selected when running the `pick` recipe.

### `just pick`

The `pick` recipe (run with `just pick` from within your project tree)
will present you a pre-filtered list of `*.just` files to pick from.

This is a convenience tool to manage the imports of your project's `justfile`.

You can have custom imports or recipes in this file, they will not be touched.

### `source just-bash`

The `just-bash` symlink (source with `source just-bash` **in every new shell**) will:

- Enable auto-completion for [Typer](https://github.com/fastapi/typer) scripts.
- Issue `nvm use`, for convenience.

### `default-just-files.txt`

Because _just-kit_ manages your `justfile`'s imports,
you should not commit it to version control.

This way, you enable yourself and collaborators to import and use arbitrary `*.just` files
from shared repositories or other sources and personalize your workflows.

On the other hand, you may want minimal onboarding overhead
by providing a set of recommended `*.just` files.
For this purpose you can create a `default-just-files.txt` file in your project tree.

The `setup` script will guide your collaborators
on how to clone the referenced repositories when they are not found
and pre-select the listed files.
You may opt out with the `--no-defaults` argument.

Each line in `default-just-files.txt` corresponds to an import statement in the `justfile`,
but in a normalized form, e.g. `https://example.com/repo:file.just`
would translate to e.g. `import '../repo/file.just'`,
depending on where you have cloned it to locally.
Override comments (see [Automatic duplicate selection](#automatic-duplicate-selection))
are supported as well.

You can create the `default-just-files.txt` file from your `justfile` at any time
by running the `lock` script of this repository, e.g.:

```bash
cd /path/to/your/project
~/.just/kit/lock
```

Be sure to move project-specific recipes that you want to keep within the repository
out of the `justfile` to `*.just` files in your project root (or into a `.just` subdirectory),
so that you do not need to commit the `justfile`.

## Adding features to your justfile

### Location for (new) just files

`*.just` and `.just/**/*.just` files in the project root and all parent directories
are considered candidates for the selection using `just pick`.

To select `*.just` files from other locations when using `just pick`,
add or extend the `EXTRA_JUST_ROOTS` variable with the respective paths
(either in the environment or in the `.env` file in your project root).
Multiple paths need to be separated with `:`.
`*.just` files in `EXTRA_JUST_ROOTS` are searched recursively.

### Selection of (new) just files

Run `just pick` from within your project tree to select new `*.just` files.

#### Duplicate recipes

When there are duplicate recipes, you are asked to choose
which `*.just` file containing the conflicting recipe(s) should override the other,
defining the import order.

##### Automatic duplicate selection

The selection is remembered for the next time
through a comment next to the import statement.

When the choice is trivial due to empty recipes or recipes having the comment `dummy`,
the non-empty or non-dummy recipe will be selected to override the other automatically.

An example dummy recipe that would be selected to be overridden automatically
(when the other recipe is non-empty and non-dummy):

```just
# dummy
[no-exit-message]
build:
    echo >&2 "ERROR: No final build recipe added to justfile."
    exit 1
```

### Hiding just files

A `_check-justile-relevance` recipe may be added to a `*.just` file
to be able to hide it from the list if not relevant for your current project
(non-zero exit code will hide it).

Note that this recipe is executed with `bash` if no `[script]` attribute is set
(ignoring the `shell` setting).

Example recipe to hide a `*.just` file when there is no `poetry` tool installed:

```just
_check-justile-relevance:
    @command -v poetry
```

Example recipe to hide a `*.just` file when there is no `.env` file in your project's root:

```just
_check-justile-relevance:
    @[ -f .env ]
```

## Running python scripts

You can forward a command to a self-contained python app powered by [uv](https://github.com/astral-sh/uv):

```just
[no-cd]
[positional-arguments]
my-python-app *ARGS:
    @"{{justfile_directory()}}/scripts/my-app.py" "$@"
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

You can also write your script [directly within the justfile](https://just.systems/man/en/python-recipes-with-uv.html).

If you do not like those comments, you can instead provide the required configuration
by running `uv` directly:

```just
[no-cd]
[positional-arguments]
my-python-app *ARGS:
    @uv run --no-project --python 3.12 --with typer "{{justfile_directory()}}/scripts/my-app.py" "$@"
```

Or if you want to use `uv` from within your project:

```just
[no-cd]
[positional-arguments]
my-python-app *ARGS:
    @uv run --project "{{justfile_directory()}}" "{{justfile_directory()}}/scripts/my-app.py" "$@"
```

See <https://docs.astral.sh/uv/guides/scripts/> for more information.

### Auto-completion with Typer

Running `source just-bash` will enable auto-completion
for [Typer](https://github.com/fastapi/typer) apps
when their recipe has the special argument `*TYPER_ARGS`.

Example for a just recipe that will have auto-completion:

```just
[no-cd]
[positional-arguments]
my-typer-app *TYPER_ARGS:
    @"{{justfile_directory()}}/scripts/my-typer-app.py" "$@"
```

Example for a just recipe that will have auto-completions using a separate completer:

```just
[no-cd]
[script("sh")]
[positional-arguments]
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
[positional-arguments]
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

### Prerequisites

- [uv](https://docs.astral.sh/uv/getting-started/installation/#installing-uv)

### Setup for development

```bash
uv run pre-commit install
```
