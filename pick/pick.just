# Pick from nearby *.just files and EXTRA_JUST_ROOTS
[script]
[no-exit-message]
[group: "maintenance"]
pick CHECK_RELEVANCE="true":
    "{{source_directory()}}/pick.sh" "{{ CHECK_RELEVANCE }}"
