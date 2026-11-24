#!/usr/bin/env bash
# Regenerates test/fixtures/signed_payload.json: a synthetic Fayda payload
# signed the way real V4 cards are (detached RS256 JWS), with a throwaway key.
# The private key is discarded; only the public key and payload are kept.
# All data is fake. Requires openssl and python3.
set -euo pipefail

cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$work/key.pem" 2>/dev/null
openssl pkey -in "$work/key.pem" -pubout -out "$work/pub.pem"

header="$(printf '%s' '{"alg":"RS256"}' | b64url)"
external='UklGRgAAAAA:DLT:Synthetic Person:V:4:G:F:A:6140123412341234:D:2000/01/02'
signing_input="$header.$(printf '%s' "$external" | b64url)"
signature="$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$work/key.pem" | b64url)"

python3 - "$work/pub.pem" "$external:SIGN:$header..$signature" <<'PY'
import json, sys
pem = open(sys.argv[1]).read().strip()
json.dump(
    {
        "$comment": "Synthetic payload signed with a throwaway key by tool/generate_signed_fixture.sh. All data is fake.",
        "publicKeyPem": pem,
        "payload": sys.argv[2],
    },
    open("test/fixtures/signed_payload.json", "w"),
    indent=2,
)
PY
echo "wrote test/fixtures/signed_payload.json"
