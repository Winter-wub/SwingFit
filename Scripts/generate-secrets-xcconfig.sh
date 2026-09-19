#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
env_file="$project_root/.env"
output_file="$project_root/Config/Secrets.xcconfig"

if [ ! -f "$env_file" ]; then
    printf '%s\n' "Missing $env_file. Copy .env.example to .env and set GEMINI_API_KEY (or OPENROUTER_API_KEY)." >&2
    exit 1
fi

openrouter_key=$(grep '^OPENROUTER_API_KEY=' "$env_file" 2>/dev/null | tail -n 1 | cut -d '=' -f 2- | tr -d '\r' || true)
gemini_key=$(grep '^GEMINI_API_KEY=' "$env_file" 2>/dev/null | tail -n 1 | cut -d '=' -f 2- | tr -d '\r' || true)

if [ -z "$openrouter_key" ] && [ -z "$gemini_key" ]; then
    printf '%s\n' 'Neither GEMINI_API_KEY nor OPENROUTER_API_KEY is found in .env.' >&2
    exit 1
fi

umask 077
cat > "$output_file" <<EOF
// Generated from .env. Do not commit this file.
OPENROUTER_API_KEY = $openrouter_key
GEMINI_API_KEY = $gemini_key
EOF

printf '%s\n' 'Generated Config/Secrets.xcconfig with configured keys.'
