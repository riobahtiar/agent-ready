#!/usr/bin/env bash
# hermes-hash-password.sh — read a password on stdin, print a Hermes dashboard
# password hash: scrypt$<n>$<r>$<p>$<salt_b64>$<dk_b64>
#
# Same format as plugins.dashboard_auth.basic.hash_password(). Hermes runs in
# an isolated runtime whose deps aren't importable from outside, so we compute
# it with the system python3's stdlib instead. The parameters come from the
# installed Hermes source when present, and the verifier reads n/r/p back out
# of the string, so this stays valid even if the defaults change. The password
# never goes on a command line (it would show in `ps`).
set -Eeuo pipefail

src="${HERMES_SRC:-$HOME/.hermes/hermes-agent}/plugins/dashboard_auth/basic/__init__.py"

HERMES_AUTH_SRC="$src" exec python3 -I -c '
import base64, hashlib, os, re, secrets, sys

params = {"N": 2**14, "R": 8, "P": 1, "DKLEN": 32, "SALT_BYTES": 16}
try:
    text = open(os.environ["HERMES_AUTH_SRC"], encoding="utf-8").read()
    for key in params:
        m = re.search(r"^_SCRYPT_%s\s*=\s*(?:2\s*\*\*\s*(\d+)|(\d+))\s*$" % key, text, re.M)
        if m:
            params[key] = 2 ** int(m.group(1)) if m.group(1) else int(m.group(2))
except OSError:
    pass

password = sys.stdin.read().removesuffix("\n")
if not password:
    sys.exit("hermes-hash-password: empty password on stdin")
salt = secrets.token_bytes(params["SALT_BYTES"])
dk = hashlib.scrypt(password.encode(), salt=salt, n=params["N"], r=params["R"], p=params["P"],
                    dklen=params["DKLEN"], maxmem=0)
print("scrypt$%d$%d$%d$%s$%s" % (params["N"], params["R"], params["P"],
      base64.b64encode(salt).decode(), base64.b64encode(dk).decode()))
'
