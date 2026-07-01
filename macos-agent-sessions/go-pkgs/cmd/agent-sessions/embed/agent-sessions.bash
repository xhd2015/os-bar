# Bash completion for agent-sessions (full command tree).
# Installed to $HOME/.config/agent-sessions/bash-completion.bash

_agent_sessions() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local top_level="notify list status config-location install integrations logs remove watch serve"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "${top_level}" -- "${cur}"))
        return 0
    fi

    local cmd="${COMP_WORDS[1]}"
    case "${cmd}" in
        notify)
            COMPREPLY=($(compgen -W "--event --dir --payload --debug-http -h --help" -- "${cur}"))
            ;;
        list)
            COMPREPLY=($(compgen -W "--limit -h --help" -- "${cur}"))
            ;;
        status|config-location)
            COMPREPLY=($(compgen -W "-h --help" -- "${cur}"))
            ;;
        install)
            COMPREPLY=($(compgen -W "--pi --opencode --grok --codex --claude --dry-run --global -h --help" -- "${cur}"))
            ;;
        integrations)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                COMPREPLY=($(compgen -W "bash-completions codex grok pi opencode claude --json --global --local -h --help" -- "${cur}"))
            elif [[ ${COMP_CWORD} -ge 3 && "${COMP_WORDS[2]}" == "bash-completions" ]]; then
                COMPREPLY=($(compgen -W "--install --dry-run -h --help" -- "${cur}"))
            elif [[ ${COMP_CWORD} -ge 3 && "${COMP_WORDS[2]}" =~ ^(codex|grok|pi|opencode|claude)$ ]]; then
                COMPREPLY=($(compgen -W "--install --dry-run --global -h --help" -- "${cur}"))
            else
                COMPREPLY=($(compgen -W "--json --global --local -h --help" -- "${cur}"))
            fi
            ;;
        logs)
            COMPREPLY=($(compgen -W "--limit --json -h --help" -- "${cur}"))
            ;;
        remove)
            COMPREPLY=($(compgen -W "--dir -h --help" -- "${cur}"))
            ;;
        watch)
            COMPREPLY=($(compgen -W "--dir --debounce-ms --event -h --help" -- "${cur}"))
            ;;
        serve)
            COMPREPLY=($(compgen -W "-h --help" -- "${cur}"))
            ;;
    esac
}

complete -F _agent_sessions agent-sessions