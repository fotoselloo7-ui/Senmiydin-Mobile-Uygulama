#!/usr/bin/env bash
# SenMiydin production deploy on the cPanel host (TürkTicaret, account alac6ayazilimtr). Idempotent: run it after every
# `git pull`. No secret lives in this file: the database / mail passwords are generated on the server the first time and
# only written to backend/.env (git-ignored, mode 600); private key files are read from ~/senmiydin_secrets/.
#
#   ~/senmiydin_src            sparse clone of the repository (backend only)
#   ~/senmiydin_src/backend    the Laravel app (APP)
#   ~/senmiydin.tr             document root of the addon domain -> symlink to APP/public
#   ~/senmiydin_secrets/       firebase-adminsdk.json, AuthKey_<APPLE_KEY_ID>.p8, REVIEW_ACCOUNT.txt (mode 600)
#
# Usage: bash ~/senmiydin_src/backend/deploy/cpanel_deploy.sh
set -euo pipefail

P=/opt/cpanel/ea-php83/root/usr/bin/php
CPUSER="$(whoami)"
APP="$HOME/senmiydin_src/backend"
DOCROOT="$HOME/senmiydin.tr"
SECRETS="$HOME/senmiydin_secrets"
DB_NAME="${CPUSER}_senmiydin.tr"
DB_USER="${CPUSER}_senmiydintr"
DOMAIN="senmiydin.tr"
cd "$APP"

setenv() { # setenv KEY VALUE  (VALUE must not contain '|')
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else printf '%s=%s\n' "$1" "$2" >> .env; fi
}
genpw() { openssl rand -hex 20; }

mkdir -p "$SECRETS" && chmod 700 "$SECRETS"

if [ ! -f .env ]; then
  echo "== first run: creating .env"
  cp .env.example .env
  chmod 600 .env
  dbpw="$(genpw)"
  uapi --output=json Mysql set_password user="$DB_USER" password="$dbpw" | grep -q '"status":1' \
    || { echo "could not set the database password"; exit 1; }
  setenv DB_HOST localhost
  setenv DB_DATABASE "$DB_NAME"
  setenv DB_USERNAME "$DB_USER"
  setenv DB_PASSWORD "$dbpw"
  # Outgoing mail from destek@senmiydin.tr on this host (mailbox created here if it does not exist yet).
  mailpw="$(genpw)"
  if uapi --output=json Email list_pops regex="^destek@$DOMAIN\$" | grep -q "destek@$DOMAIN"; then
    uapi --output=json Email passwd_pop email=destek domain="$DOMAIN" password="$mailpw" >/dev/null
  else
    uapi --output=json Email add_pop email=destek domain="$DOMAIN" password="$mailpw" quota=2048 >/dev/null
  fi
  uapi --output=json Email list_pops regex="^info@$DOMAIN\$" | grep -q "info@$DOMAIN" \
    || uapi --output=json Email add_pop email=info domain="$DOMAIN" password="$(genpw)" quota=2048 >/dev/null
  setenv MAIL_HOST "$(hostname -f)"
  setenv MAIL_USERNAME "destek@$DOMAIN"
  setenv MAIL_PASSWORD "$mailpw"
  setenv MAIL_FROM_ADDRESS "destek@$DOMAIN"
  "$P" artisan key:generate --force
fi

# Values that may change between deploys (all public or file paths).
setenv APP_ENV production
setenv APP_DEBUG false
setenv MINIMUM_AGE 16
setenv FCM_CREDENTIALS "$SECRETS/firebase-adminsdk.json"
setenv APPLE_PRIVATE_KEY_PATH "$SECRETS/AuthKey_$(grep '^APPLE_KEY_ID=' .env | cut -d= -f2).p8"
setenv SCHEDULER_CONFIGURED true
setenv QUEUE_WORKER_CONFIGURED true

"$P" ~/bin/composer.phar install --no-dev --optimize-autoloader --no-interaction --quiet
"$P" artisan down --retry=30 || true
"$P" artisan migrate --force
"$P" artisan db:seed --force
[ -L public/storage ] || "$P" artisan storage:link
"$P" artisan optimize:clear >/dev/null
"$P" artisan config:cache
"$P" artisan route:cache
"$P" artisan view:cache
"$P" artisan up

# Review account (password from the private REVIEW_ACCOUNT.txt; never printed).
if [ -f "$SECRETS/REVIEW_ACCOUNT.txt" ]; then
  REVIEW_ACCOUNT_PASSWORD="$(sed -n 's/^password: //p' "$SECRETS/REVIEW_ACCOUNT.txt")" "$P" artisan app:review-account
fi

# Document root -> public (the addon domain directory holds nothing else).
if [ ! -L "$DOCROOT" ]; then
  rm -rf "$DOCROOT"
  ln -s "$APP/public" "$DOCROOT"
fi

# Scheduler + queue worker (shared hosting: one worker pass per minute).
CRON_SCHED="* * * * * cd $APP && $P artisan schedule:run >> /dev/null 2>&1"
CRON_QUEUE="* * * * * cd $APP && $P artisan queue:work --stop-when-empty --max-time=55 --tries=3 >> /dev/null 2>&1"
{ crontab -l 2>/dev/null | grep -v "senmiydin_src/backend" || true; echo "$CRON_SCHED"; echo "$CRON_QUEUE"; } | crontab -

chmod -R ug+rwX storage bootstrap/cache
echo "== deploy finished"
"$P" artisan app:check || true
