# Удаляет сохранённые пароли/автозаполнение из ВСЕХ профилей Google Chrome.
#
# По умолчанию — сухой прогон (только показывает, что найдено).
# Реальное удаление: --yes
#
# ВАЖНО: перед запуском выгрузите пароли в KeePassXC, иначе они пропадут
# безвозвратно. См. README рядом с module/chrome-password-manager.nix.

set -euo pipefail

APPLY=0
WITH_AUTOFILL=0
for arg in "$@"; do
  case "$arg" in
    --yes) APPLY=1 ;;
    --with-autofill) WITH_AUTOFILL=1 ;;
    -h|--help)
      echo "usage: chrome-purge-passwords [--yes] [--with-autofill]"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

# Все user-data-dir, которые использует эта конфигурация.
ROOTS=(
  "$HOME/.config/google-chrome"
  "$HOME/.config/google-chrome-debug"
  "$HOME/.config/google-chrome-mcp"
  "$HOME/.config/chromium"
)

# Лок нужен только для записи. Сухой прогон читает базы через
# immutable=1 и работает при открытом Chrome.
if pgrep -x chrome >/dev/null 2>&1 || pgrep -f 'google-chrome' >/dev/null 2>&1; then
  if [ "$APPLY" -eq 1 ]; then
    echo "Chrome запущен — закройте его полностью (SQLite-базы залочены)." >&2
    exit 1
  fi
  echo "note: Chrome запущен; это только сухой прогон (чтение read-only)."
  echo
fi

# Таблицы с учётными данными внутри "Login Data" / "Login Data For Account".
PASSWORD_TABLES=(logins stats insecure_credentials password_notes field_info)
# Таблицы автозаполнения внутри "Web Data".
AUTOFILL_TABLES=(
  autofill
  autofill_profiles
  autofill_profile_names
  autofill_profile_emails
  autofill_profile_phones
  autofill_profile_addresses
  local_addresses
  local_addresses_type_tokens
  credit_cards
  local_stored_cvc
  masked_credit_cards
  server_card_metadata
  ibans
  local_ibans
)

BACKUP_DIR="$HOME/.local/share/chrome-password-purge/$(date +%Y%m%d-%H%M%S)"

# Read-only URI: не берёт лок, поэтому счётчики видны даже при
# запущенном Chrome. Пробелы в "Login Data" надо percent-энкодить.
ro_uri() {
  printf 'file:%s?immutable=1' "${1// /%20}"
}

table_exists() {
  local db table=$2
  db=$(ro_uri "$1")
  [ "$(sqlite3 "$db" \
    "select count(*) from sqlite_master where type='table' and name='$table';")" != "0" ]
}

row_count() {
  local db table=$2
  db=$(ro_uri "$1")
  if table_exists "$1" "$table"; then
    sqlite3 "$db" "select count(*) from \"$table\";"
  else
    echo 0
  fi
}

purge_db() {
  local db=$1
  shift
  local tables=("$@")
  local total=0 n

  for t in "${tables[@]}"; do
    n=$(row_count "$db" "$t")
    total=$((total + n))
    [ "$n" -gt 0 ] && printf '    %-32s %s\n' "$t" "$n"
  done

  if [ "$total" -eq 0 ]; then
    echo "    (пусто)"
    return
  fi

  if [ "$APPLY" -eq 0 ]; then
    echo "    -> будет удалено $total записей (сухой прогон)"
    return
  fi

  mkdir -p "$BACKUP_DIR"
  cp -- "$db" "$BACKUP_DIR/$(echo "${db#"$HOME/"}" | tr '/' '_')"

  for t in "${tables[@]}"; do
    if table_exists "$db" "$t"; then
      sqlite3 "$db" "delete from \"$t\";"
    fi
  done
  sqlite3 "$db" "vacuum;"
  echo "    -> удалено $total записей"
}

found=0
for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue
  while IFS= read -r -d '' db; do
    found=1
    echo "${db#"$HOME/"}"
    purge_db "$db" "${PASSWORD_TABLES[@]}"
  done < <(find "$root" -maxdepth 2 \
    \( -name 'Login Data' -o -name 'Login Data For Account' \) -print0)

  if [ "$WITH_AUTOFILL" -eq 1 ]; then
    while IFS= read -r -d '' db; do
      echo "${db#"$HOME/"}"
      purge_db "$db" "${AUTOFILL_TABLES[@]}"
    done < <(find "$root" -maxdepth 2 -name 'Web Data' -print0)
  fi
done

if [ "$found" -eq 0 ]; then
  echo "Профили Chrome не найдены."
  exit 0
fi

if [ "$APPLY" -eq 0 ]; then
  echo
  echo "Это был сухой прогон. Для реального удаления: chrome-purge-passwords --yes"
else
  echo
  echo "Бэкапы: $BACKUP_DIR"
  echo "Не забудьте также удалить пароли из аккаунта Google:"
  echo "  https://passwords.google.com  (иначе синхронизация вернёт их обратно)"
fi
