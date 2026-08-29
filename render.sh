#!/usr/bin/env bash
# render.sh — substitute <UPPER_CASE> tokens in every *.tmpl file with the
# values from config.env, writing the deploy-ready file next to each template.
#
#   cp config.env.example config.env && $EDITOR config.env && ./render.sh
#
# Convention: a token matching <[A-Z][A-Z0-9_]*> is a render variable and MUST
# be substituted. Anything else is literal. After rendering, every output is
# scanned for leftover tokens — a single leftover fails the whole run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONF="$ROOT/config.env"

if [ ! -f "$CONF" ]; then
	echo "run: cp config.env.example config.env && edit it" >&2
	exit 1
fi

# --- parse config.env into a sed script -------------------------------------
SED_SCRIPT="$(mktemp)"
trap 'rm -f "$SED_SCRIPT"' EXIT

while IFS= read -r line || [ -n "$line" ]; do
	# skip blank lines and comments
	case "$line" in
		''|\#*) continue ;;
	esac
	# split on the first '='
	case "$line" in
		*=*) ;;
		*) continue ;;
	esac
	key="${line%%=*}"
	value="${line#*=}"
	# trim surrounding whitespace and an optional leading "export "
	key="${key#export }"
	key="${key#"${key%%[![:space:]]*}"}"
	key="${key%"${key##*[![:space:]]}"}"
	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"

	case "$key" in
		[A-Z][A-Z0-9_]*) ;;
		*)
			echo "config.env: key '$key' is not UPPER_CASE — tokens are <[A-Z][A-Z0-9_]*>" >&2
			exit 1
			;;
	esac
	case "$value" in
		*"|"*)
			echo "config.env: value of '$key' contains '|', which render.sh uses as the sed delimiter" >&2
			exit 1
			;;
	esac

	printf 's|<%s>|%s|g\n' "$key" "$value" >>"$SED_SCRIPT"
done <"$CONF"

# --- render every *.tmpl ----------------------------------------------------
count=0
rendered_files=""
while IFS= read -r tmpl; do
	out="${tmpl%.tmpl}"
	sed -f "$SED_SCRIPT" "$tmpl" >"$out"
	# sed > out uses the umask; carry the template's execute bit to the output
	[ -x "$tmpl" ] && chmod +x "$out"
	rendered_files="$rendered_files $out"
	count=$((count + 1))
done <<EOF
$(find "$ROOT" -name '*.tmpl' -not -path '*/.git/*' | sort)
EOF

# --- fail-loud gate: no <UPPER_CASE> token may survive in any output -------
leftover=0
for out in $rendered_files; do
	while IFS= read -r hit; do
		[ -n "$hit" ] || continue
		leftover=1
		lineno="${hit%%:*}"
		rest="${hit#*:}"
		token="$(printf '%s\n' "$rest" | grep -o '<[A-Z][A-Z0-9_]*>' | head -n1)"
		key="${token#<}"
		key="${key%>}"
		echo "$out:$lineno: unsubstituted $token — add '$key=' to config.env" >&2
	done <<EOF
$(grep -nE '<[A-Z][A-Z0-9_]*>' "$out" || true)
EOF
done

if [ "$leftover" -ne 0 ]; then
	echo "render failed: unsubstituted tokens remain (rendered files left in place for inspection)" >&2
	exit 1
fi

echo "rendered $count files from config.env"
