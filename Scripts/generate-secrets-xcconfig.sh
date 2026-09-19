#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
env_file="$project_root/.env"
output_file="$project_root/Config/Secrets.xcconfig"

if [ ! -f "$env_file" ]; then
    printf '%s\n' "Missing $env_file. Copy .env.example to .env and set OPENROUTER_API_KEY." >&2
    exit 1
fi

api_key=$(grep '^OPENROUTER_API_KEY=' "$env_file" | tail -n 1 | cut -d '=' -f 2- | tr -d '\r')

if [ -z "$api_key" ]; then
    printf '%s\n' 'OPENROUTER_API_KEY is missing or empty in .env.' >&2
    exit 1
fi

case "$api_key" in
    *[!A-Za-z0-9._-]*)
        printf '%s\n' 'OPENROUTER_API_KEY contains unsupported characters for an xcconfig value.' >&2
        exit 1
        ;;
esac

umask 077
cat > "$output_file" <<EOF
// Generated from .env. Do not commit this file.
OPENROUTER_API_KEY = $api_key
EOF

printf '%s\n' 'Generated Config/Secrets.xcconfig.'
