# Completions for proxify command
# Suggests available commands, functions, and aliases

function __proxify_complete
    command -a
    functions
    alias | string replace -r 'alias (.+)=.*' '$1'
end

complete -c proxify -f -a "(__proxify_complete)"
