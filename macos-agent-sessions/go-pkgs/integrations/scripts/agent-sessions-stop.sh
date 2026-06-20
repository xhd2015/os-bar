#!/bin/sh
# os-bar agent-sessions Stop hook.
# Reads hook event JSON from stdin and notifies the agent-sessions server.
# Set AGENT_SESSIONS_AGENT to "grok" or "codex" via hooks.json env.

INPUT=$(cat)
AGENT="${AGENT_SESSIONS_AGENT:-unknown}"

extract_with_jq() {
	key="$1"
	echo "$INPUT" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null
}

extract_with_python() {
	key="$1"
	echo "$INPUT" | python3 -c 'import json,sys
key=sys.argv[1]
try:
    data=json.load(sys.stdin)
except Exception:
    sys.exit(1)
val=data.get(key)
if val is None:
    sys.exit(1)
print(val if isinstance(val, str) else "")' "$key" 2>/dev/null
}

extract_with_node() {
	key="$1"
	echo "$INPUT" | node -e 'const fs=require("fs");const key=process.argv[1];let data;try{data=JSON.parse(fs.readFileSync(0,"utf8"))}catch{process.exit(1)}const val=data[key];if(val==null||typeof val!=="string")process.exit(1);process.stdout.write(val)' "$key" 2>/dev/null
}

extract_with_grep() {
	key="$1"
	echo "$INPUT" | grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/'
}

extract_field() {
	key="$1"
	val=""

	if command -v jq >/dev/null 2>&1; then
		val=$(extract_with_jq "$key")
		[ -n "$val" ] && echo "$val" && return 0
	fi

	if command -v python3 >/dev/null 2>&1; then
		val=$(extract_with_python "$key")
		[ -n "$val" ] && echo "$val" && return 0
	fi

	if command -v node >/dev/null 2>&1; then
		val=$(extract_with_node "$key")
		[ -n "$val" ] && echo "$val" && return 0
	fi

	val=$(extract_with_grep "$key")
	[ -n "$val" ] && echo "$val" && return 0
	return 1
}

DIR="${GROK_WORKSPACE_ROOT:-${CLAUDE_PROJECT_DIR:-}}"
if [ -z "$DIR" ]; then
	DIR=$(extract_field cwd || true)
fi
if [ -z "$DIR" ]; then
	DIR=$(extract_field workspaceRoot || true)
fi

SESSION="${GROK_SESSION_ID:-}"
if [ -z "$SESSION" ]; then
	SESSION=$(extract_field sessionId || true)
fi
if [ -z "$SESSION" ]; then
	SESSION=$(extract_field session_id || true)
fi

if [ -z "$DIR" ]; then
	exit 0
fi

if [ -n "$SESSION" ]; then
	PAYLOAD=$(printf '{"source":"notify","event":"session.finished","dir":"%s","%s":{"sessionId":"%s","nativeEvent":"Stop"}}' \
		"$DIR" "$AGENT" "$SESSION")
else
	PAYLOAD=$(printf '{"source":"notify","event":"session.finished","dir":"%s","%s":{"sessionId":null,"nativeEvent":"Stop"}}' \
		"$DIR" "$AGENT")
fi

if command -v agent-sessions >/dev/null 2>&1; then
	agent-sessions notify --payload "$PAYLOAD" >/dev/null 2>&1 &
	exit 0
fi

exit 0