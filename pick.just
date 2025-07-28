import 'settings.just'

# Pick from nearby *.just files and EXTRA_JUST_ROOTS
[script("sh")]
[no-exit-message]
[group: "maintenance"]
pick CHECK_RELEVANCE="true":
    "{{source_directory()}}/pick/pick.sh" "{{CHECK_RELEVANCE}}"
