# Abbreviations — ported from the laptop config (functions/aliases/*.fish).
# Abbreviations expand inline before you run them, so you always see the real
# command. Remove any with `abbr --erase <name>`.

# ─── git ───
abbr -a g-dev 'git checkout develop && git pull origin develop'
abbr -a g-puo 'git push -u origin'
abbr -a g-s 'git stash'
abbr -a g-s-list 'git stash list'
abbr -a lg lazygit
abbr -a gst 'git status -sb'
abbr -a gco 'git checkout'
abbr -a gpr 'gh pr create --fill'
abbr -a ghw 'gh pr view --web'

# ─── docker ───
function sail --description "Laravel Sail (./sail or vendor/bin/sail)"
    if test -f sail
        command sh sail $argv
    else if test -f vendor/bin/sail
        command sh vendor/bin/sail $argv
    else
        echo "sail: no ./sail or vendor/bin/sail in this directory" >&2
        return 127
    end
end

abbr -a lzd lazydocker
# `dco`, not `dc`: /usr/bin/dc is the POSIX desk calculator — don't shadow it
abbr -a dco 'docker compose'
abbr -a dcu 'docker compose up'
abbr -a dcud 'docker compose up -d'
abbr -a dcd 'docker compose down'
abbr -a dcl 'docker compose logs -f'
abbr -a dce 'docker compose exec'
abbr -a dcr 'docker compose run --rm'
abbr -a dcb 'docker compose build'
abbr -a dps 'docker ps'
abbr -a dpsa 'docker ps -a'
abbr -a dprune 'docker system prune -f'

# ─── js (bun / node via mise) ───
abbr -a br 'bun run'
abbr -a bx bunx
abbr -a bi 'bun install'
abbr -a ba 'bun add'
abbr -a bd 'bun run dev'
abbr -a bt 'bun test'
abbr -a bld 'bun run build'

abbr -a nr 'npm run'
abbr -a nrd 'npm run dev'
abbr -a ni 'npm install'

# ─── mise / python / go ───
abbr -a mu 'mise use'
abbr -a mug 'mise use -g'
abbr -a mi 'mise install'
abbr -a ml 'mise ls'

abbr -a uvr 'uv run'
abbr -a uva 'uv add'
abbr -a uvs 'uv sync'
abbr -a rf 'ruff check --fix'
abbr -a rff 'ruff format'

abbr -a gci 'golangci-lint run'

# ─── flutter ───
abbr -a fl flutter
abbr -a flr 'flutter run'
abbr -a flb 'flutter build'
abbr -a flt 'flutter test'
abbr -a flc 'flutter clean'
abbr -a flpg 'flutter pub get'
abbr -a flpu 'flutter pub upgrade'
abbr -a fld 'dart run'

# ─── laravel / php (Ubuntu php-fpm + composer) ───
abbr -a art 'php artisan'
abbr -a pa 'php artisan'
abbr -a tinker 'php artisan tinker'
abbr -a migrate 'php artisan migrate'
abbr -a mfs 'php artisan migrate:fresh --seed'
abbr -a serve 'php artisan serve'

abbr -a pint './vendor/bin/pint'
abbr -a pest './vendor/bin/pest'

abbr -a co composer
abbr -a ci 'composer install'
abbr -a cu 'composer update'
abbr -a cda 'composer dump-autoload'

# ─── hosting / ops (bin/ commands; each opens a menu when run bare) ───
abbr -a v vps
abbr -a sa 'site add'
abbr -a sl 'site ls'
abbr -a ua update-all
abbr -a uaa 'update-all agents'
abbr -a cln cleanup
abbr -a lports 'sudo ss -tlnp'
abbr -a jf 'journalctl -f -u'
abbr -a sc 'sudo systemctl'
abbr -a scu 'systemctl --user'
abbr -a tn tunnel
abbr -a sbx sandbox

# ─── cloud (AWS · Cloudflare · rclone) ───
abbr -a s3 'aws s3'
abbr -a wr wrangler
abbr -a wrd 'wrangler dev'
abbr -a wrp 'wrangler deploy'
abbr -a cfs 'cf cli search'
