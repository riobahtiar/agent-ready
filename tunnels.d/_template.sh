# shellcheck shell=bash
# tunnels.d/<id>.sh — one dev-tunnel provider. Files starting with "_" are skipped.
#   reach: private (only you) · public (anyone with the URL) · permanent (real domain)
#   rank:  lower is tried first by `tunnel <port>` without a provider
#   auto=no keeps it out of automatic selection (needs input, or prints only)
tunnel_define ID title="Short description" reach=public rank=50 setup="how to get it ready"

ID_ready() { have ID || {
    echo "install ID"
    return 1
}; }
# Print the URL on stdout. Long-running clients go through tunnel_bg.
ID_start() { tunnel_bg ID "$1" 'https://[a-z0-9.-]+\.example\.com' ID http "127.0.0.1:$1"; }
