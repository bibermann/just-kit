import 'settings.just'

# Pick from nearby *.just files and EXTRA_JUST_ROOTS
[script("sh")]
[no-exit-message]
[group: "maintenance"]
pick CHECK_RELEVANCE="true":
    if "{{source_directory()}}/pick/pick.sh" "{{CHECK_RELEVANCE}}"; then
        just _just_bash_hint
    fi

[script("sh")]
_just_bash_hint:
    if [ -z "${IS_JUST_BASH_SOURCED+x}" ] && \
      {
        [ -f "$HOME/.nvm/nvm.sh" ] || \
        { [ -f justfile ] && grep -q -E '\*TYPER_ARGS\b' justfile; } || \
        { [ -f Justfile ] && grep -q -E '\*TYPER_ARGS\b' Justfile; } || \
        { [ -f .justfile ] && grep -q -E '\*TYPER_ARGS\b' .justfile; } || \
        { [ -f .Justfile ] && grep -q -E '\*TYPER_ARGS\b' .Justfile; }
      }; then
        printf '\n'
        printf '\e[1mHint:\e[0m'
        printf ' Run '"'"'source just-bash'"'"' to '
        printf '\e]8;;https://github.com/bibermann/just-kit?tab=readme-ov-file#source-just-bash\e\\enhance your bash session\e]8;;\e\\'
        printf '.\n'
    fi
