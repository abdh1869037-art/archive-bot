#!/usr/bin/env bash
set -Eeuo pipefail

DB_FILE="archive_bot.db"
BRANCH="${GITHUB_REF_NAME:-main}"
LOCK_FILE="${RUNNER_TEMP:-/tmp}/archive-bot-db-save.lock"

persist_once() {
  # يمنع تشغيل حفظين متزامنين داخل المهمة نفسها.
  exec 9>"$LOCK_FILE"
  flock -n 9 || return 0

  if [[ ! -f "$DB_FILE" ]]; then
    echo "لا توجد قاعدة بيانات لحفظها بعد."
    return 0
  fi

  git add -- "$DB_FILE"
  if git diff --cached --quiet -- "$DB_FILE"; then
    echo "لا توجد تغييرات جديدة في $DB_FILE."
    return 0
  fi

  git commit -m "Persist archive database [skip ci]" -- "$DB_FILE"
  git pull --rebase --autostash origin "$BRANCH"
  git push origin "HEAD:$BRANCH"
  echo "تم دفع آخر نسخة من $DB_FILE إلى الفرع $BRANCH."
}

if [[ "${1:-}" == "--loop" ]]; then
  trap 'exit 0' TERM INT
  while true; do
    persist_once || echo "فشل الحفظ الدوري؛ ستُعاد المحاولة بعد 30 دقيقة." >&2
    sleep 1800 &
    wait $!
  done
else
  persist_once
fi
