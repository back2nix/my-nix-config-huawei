#!/usr/bin/env bash
# Подбор стратегий zapret2 под текущую сеть. Методика — docs/zapret2-tuning.md.
#
# Для каждой стратегии из module/zapret2/candidates.txt поднимает nfqws2 с этой
# одной стратегией на весь tcp/443 и проверяет напрямую (без прокси) каждый
# домен из module/zapret2/hosts.txt: прошёл ли TLS-handshake. Домен получает
# первую по списку рабочую стратегию. Результат — module/zapret2/profiles.json,
# его читает module/zapret2.nix; применяется обычным `just switch`.
#
# Запуск: just zapret-tune            (нужен root: nfqueue и nftables)
#         just zapret-tune --dry-run  (только отчёт, profiles.json не трогать)
#         just zapret-check           (без root: что не открывается прямо сейчас)
#
# На время подбора боевая служба остановлена, в конце возвращается как была.
# `just switch` во время подбора не запускать: он поднимет службу, и замеры
# смешаются (скрипт это заметит и прервётся).
set -euo pipefail

DRY=0
CHECK=0
case "${1:-}" in
  --dry-run) DRY=1 ;;
  --check) CHECK=1 ;;
  "") ;;
  *) echo "неизвестный аргумент: $1" >&2; exit 2 ;;
esac

REPO=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
HOSTS=$REPO/module/zapret2/hosts.txt
CANDIDATES=$REPO/module/zapret2/candidates.txt
PROBES=$REPO/module/zapret2/probe-hosts.txt
OUT=$REPO/module/zapret2/profiles.json
# Не задирать: под параллельной нагрузкой сеть даёт ложные отказы даже там,
# где стратегия рабочая. Проверено на этой сети: при 32 потоках «упали» Discord
# и YouTube, которые через пять минут открывались 6 раз из 6; при 8 потоках
# два прогона подряд разложили домены по-разному. Последовательно — стабильно.
JOBS=${JOBS:-4}
# Сколько раз перепроверять упавшие домены, прежде чем считать отказ настоящим.
RETRIES=${RETRIES:-2}
# Отдельные очередь и таблица, чтобы не делить их с боевой службой.
QNUM=${QNUM:-201}
TABLE=zapret2tune
CONNECT_TIMEOUT=${CONNECT_TIMEOUT:-2}
MAX_TIME=${MAX_TIME:-3}

# Проверяем прямой доступ: прокси из окружения дал бы ложный «работает».
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY

# TLS считается пройденным, если curl дошёл до конца handshake (time_appconnect
# > 0). Код ответа не важен: 403/404 от сервера — это уже «не заблокировано».
tls_ok() { # $1 = host
  local t
  t=$(curl -4 -s -o /dev/null --noproxy '*' --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$MAX_TIME" -w '%{time_appconnect}' "https://$1/" 2>/dev/null || true)
  [ -n "$t" ] && [ "$t" != "0.000000" ]
}
probe_domain() { # $1 = домен, $2.. = хосты для проверки; хватит одного рабочего
  local d=$1 h
  shift
  for h in "$@"; do
    if tls_ok "$h"; then echo "$d 1"; return; fi
  done
  echo "$d 0"
}
export -f tls_ok probe_domain
export CONNECT_TIMEOUT MAX_TIME

mapfile -t DOMAINS < <(grep -vE '^\s*(#|$)' "$HOSTS" | awk '{print $1}' | sort -u)
[ "${#DOMAINS[@]}" -gt 0 ] || { echo "пустой $HOSTS" >&2; exit 1; }

# Какие имена проверять для домена. По умолчанию — сам домен и www.
# Для CDN, где блокируют не витрину, а узлы раздачи, нужен конкретный узел:
# задаётся в probe-hosts.txt («домен хост [хост...]») или находится сам (YouTube).
declare -A PROBE
if [ -r "$PROBES" ]; then
  while read -r d rest; do
    [ -n "$d" ] && [ -n "$rest" ] && PROBE[$d]=$rest
  done < <(grep -vE '^\s*(#|$)' "$PROBES")
fi

# Видео YouTube отдаёт кэш Google у провайдера (rrN---sn-XXXX.googlevideo.com),
# и блокируют его иначе, чем youtube.com. Имя своего кэша узнаём у Google:
# report_mapping отдаёт код площадки, он переводится в sn-имя заменой букв.
detect_ggc() {
  local raw code
  raw=$(curl -4 -s --noproxy '*' --max-time 5 'https://redirector.googlevideo.com/report_mapping?di=no' 2>/dev/null || true)
  code=$(sed -n 's/.*=>[ ]*\([^ (:)]*\).*/\1/p' <<<"$raw" | head -1)
  [ -n "$code" ] || return 1
  echo "rr1---sn-$(tr 'uzpkfa50vqlgb61wrmhc72xsnid83ytoje94' '0123456789abcdefghijklmnopqrstuvwxyz' <<<"$code").googlevideo.com"
}

WORK=$(mktemp -d)
# nfqws2 после старта сбрасывает root и должен дочитаться до своих списков.
chmod 755 "$WORK"
write_targets() { # $1 = файл со списком доменов -> stdout «домен хост...»
  local d
  while read -r d; do echo "$d ${PROBE[$d]:-$d www.$d}"; done <"$1"
}
# probe_list <файл доменов> <файл результата «домен 0|1»> [файл «кого перепроверять»]
# Упавшие перепроверяются после паузы: разовый сбой не должен менять группу
# домена. Третий аргумент ограничивает перепроверку (без него — все упавшие).
probe_list() {
  local try
  write_targets "$1" | xargs -r -P "$JOBS" -L1 bash -c 'probe_domain "$@"' _ | sort >"$2"
  for try in $(seq "$RETRIES"); do
    awk '$2==0{print $1}' "$2" >"$2.retry"
    if [ -n "${3:-}" ]; then
      grep -Fxf "$3" "$2.retry" >"$2.retry2" || true
      mv "$2.retry2" "$2.retry"
    fi
    [ -s "$2.retry" ] || break
    sleep 3
    write_targets "$2.retry" | xargs -r -P "$JOBS" -L1 bash -c 'probe_domain "$@"' _ | sort >"$2.b"
    awk 'NR==FNR{b[$1]=$2;next} {print $1, ($1 in b ? b[$1] : $2)}' "$2.b" "$2" >"$2.m"
    mv "$2.m" "$2"
  done
}
# Отвечает ли хоть один проверочный хост домена на tcp/443. Если нет — сайта на
# этом имени нет или он закрыт по IP: десинхронизация тут не поможет.
tcp_domain() { # $1 = домен, $2.. = хосты
  local d=$1 h
  shift
  for h in "$@"; do
    if timeout 2 bash -c "exec 3<>/dev/tcp/$h/443" 2>/dev/null; then echo "$d 1"; return; fi
  done
  echo "$d 0"
}
export -f tcp_domain
printf '%s\n' "${DOMAINS[@]}" >"$WORK/all"

if [ "$CHECK" = 1 ]; then
  trap 'rm -rf "$WORK"' EXIT
  systemctl is-active -q zapret2 && echo "zapret2: включён" || echo "zapret2: ВЫКЛЮЧЕН (проверка без обхода)"
  if [ -z "${PROBE[googlevideo.com]:-}" ] && ggc=$(detect_ggc); then
    PROBE[googlevideo.com]=$ggc
    echo "кэш YouTube на этой сети: $ggc"
  fi
  probe_list "$WORK/all" "$WORK/res.check"
  echo "открывается напрямую: $(awk '$2==1' "$WORK/res.check" | wc -l) из ${#DOMAINS[@]}; не открывается:"
  awk '$2==0{print "    " $1}' "$WORK/res.check"
  exit 0
fi

[ "$(id -u)" = 0 ] || { echo "нужен root: sudo $0 $*" >&2; exit 1; }

# Пути берём из установленного юнита: тот же nfqws2, те же lua и правила nft,
# что и в боевой службе, — значит, результат переносится на неё один в один.
exec_start=$(systemctl show zapret2 -p ExecStart --value)
NFQWS=$(grep -o '/nix/store/[^ ;]*/bin/nfqws2' <<<"$exec_start" | head -1)
CONF=$(grep -o '@/nix/store/[^ ;]*' <<<"$exec_start" | head -1 | cut -c2-)
NFT_RULES=$(systemctl show zapret2 -p ExecStartPre --value | grep -o '/nix/store/[^ ;]*\.nft' | head -1)
[ -x "$NFQWS" ] && [ -r "$CONF" ] && [ -r "$NFT_RULES" ] || {
  echo "не нашёл nfqws2/конфиг/правила в юните zapret2 (служба установлена?)" >&2
  exit 1
}

NFQ_PID=
WAS_ACTIVE=0
systemctl is-active -q zapret2 && WAS_ACTIVE=1

stop_nfqws() {
  [ -n "$NFQ_PID" ] && kill "$NFQ_PID" 2>/dev/null && wait "$NFQ_PID" 2>/dev/null || true
  NFQ_PID=
}
cleanup() {
  stop_nfqws
  nft delete table inet "$TABLE" 2>/dev/null || true
  if [ "$WAS_ACTIVE" = 1 ]; then systemctl start zapret2 || true; fi
  rm -rf "$WORK"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

systemctl stop zapret2
# Те же правила, что у службы, но под своим именем таблицы и номером очереди.
sed -E "s/(table inet )zapret2\b/\1$TABLE/; s/(queue num )[0-9]+/\1$QNUM/" "$NFT_RULES" | nft -f -
nft list table inet "$TABLE" | grep -q "queue.* $QNUM" || { echo "не смог загрузить правила nft для проверки" >&2; exit 1; }

# Общая шапка боевого конфига (метка, lua) — всё до первого профиля.
sed '/^--name=/,$d' "$CONF" | sed -E "s/^--qnum=.*/--qnum=$QNUM/" >"$WORK/head.conf"

# Если службу подняли посреди подбора (например, `just switch`), пакеты пошли
# бы через два обхода сразу и замеры потеряли бы смысл.
guard() {
  case "$(systemctl is-active zapret2 || true)" in active | activating) ;; *) return 0 ;; esac
  {
    echo "zapret2.service запустили во время подбора — результаты недостоверны, прерываюсь." >&2
    WAS_ACTIVE=1
    exit 1
  }
}

# Тело профиля — те же фильтры, что ставит module/zapret2.nix.
profile_lines() { # $1 = --name|--new, $2 = имя, $3 = аргументы стратегии, [$4 = hostlist]
  echo "$1=$2"
  [ -n "${4:-}" ] && echo "--hostlist=$4"
  printf '%s\n' "--filter-tcp=443" "--filter-l7=tls" "--out-range=-d10" "--payload=tls_client_hello"
  tr ' ' '\n' <<<"$3"
}
start_nfqws() { # $1 = аргументы одной стратегии на весь tcp/443, либо «@файл» с готовыми профилями
  stop_nfqws
  {
    cat "$WORK/head.conf"
    if [[ $1 == @* ]]; then cat "${1#@}"; else profile_lines --name probe "$1"; fi
  } >"$WORK/probe.conf"
  "$NFQWS" "@$WORK/probe.conf" >"$WORK/nfqws.log" 2>&1 &
  NFQ_PID=$!
  sleep 1
  kill -0 "$NFQ_PID" 2>/dev/null || { NFQ_PID=; return 1; }
}

mapfile -t CAND_LINES < <(grep -vE '^\s*(#|$)' "$CANDIDATES")
[ "${#CAND_LINES[@]}" -gt 0 ] || { echo "пустой $CANDIDATES" >&2; exit 1; }

if [ -z "${PROBE[googlevideo.com]:-}" ]; then
  # Без обхода redirector недоступен, поэтому пробуем под каждым кандидатом.
  for line in "${CAND_LINES[@]}"; do
    start_nfqws "$(sed 's/^[^|]*| *//' <<<"$line")" || continue
    if ggc=$(detect_ggc); then PROBE[googlevideo.com]=$ggc; break; fi
  done
  stop_nfqws
  if [ -n "${PROBE[googlevideo.com]:-}" ]; then
    echo "кэш YouTube на этой сети: ${PROBE[googlevideo.com]}"
  else
    echo "ВНИМАНИЕ: не узнал кэш YouTube; googlevideo.com будет проверен неточно." >&2
    echo "  Задай узел вручную в $PROBES: googlevideo.com rrN---sn-XXXX.googlevideo.com" >&2
  fi
fi

echo "проверяю ${#DOMAINS[@]} доменов, ${#CAND_LINES[@]} стратегий (+ проход без обхода)"
stop_nfqws
probe_list "$WORK/all" "$WORK/res.none"
echo "  без обхода: открывается $(awk '$2==1' "$WORK/res.none" | wc -l) из ${#DOMAINS[@]}"
guard

# Стратегии подбираются только для доменов, закрытых без обхода. Открытые
# zapret не трогает вовсе (группа direct), и это не только экономия времени:
#   * обход им не нужен, а навредить может — фальшивый ClientHello ломал на
#     этой сети сайты, которые без него открывались (mozilla.org: 0 из 10);
#   * замеры открытых сайтов под стратегиями не воспроизводятся от прогона к
#     прогону (одной и той же стратегии «подходило» то 106, то 203 домена),
#     а проход без обхода стабилен (160–176 из 281).
# Имена, где на tcp/443 никто не отвечает, тоже пропускаются: каждая попытка к
# ним — полный таймаут, а помочь им стратегия не может.
awk '$2==1{print $1}' "$WORK/res.none" >"$WORK/open"
awk '$2==0{print $1}' "$WORK/res.none" >"$WORK/closed"
write_targets "$WORK/closed" | xargs -r -P 16 -L1 bash -c 'tcp_domain "$@"' _ | sort >"$WORK/res.tcp"
awk '$2==0{print $1}' "$WORK/res.tcp" >"$WORK/dead"
echo "  из закрытых не отвечают на tcp/443 (сайта нет или блок по IP, пропускаю): $(wc -l <"$WORK/dead")"

# Каждая следующая стратегия проверяет только домены, которым ещё не нашлось
# рабочей: домен получает первую подошедшую по списку, остальные ему не нужны.
NAMES=()
declare -A ARGS ASSIGN
grep -vFxf "$WORK/dead" "$WORK/closed" >"$WORK/todo" || true
while read -r d; do ASSIGN[$d]=direct; done <"$WORK/open"
for line in "${CAND_LINES[@]}"; do
  [ -s "$WORK/todo" ] || break
  name=$(sed 's/ *|.*//' <<<"$line")
  args=$(sed 's/^[^|]*| *//' <<<"$line")
  if ! start_nfqws "$args"; then
    echo "  $name: nfqws2 не запустился с этими аргументами, пропускаю:" >&2
    tail -3 "$WORK/nfqws.log" >&2
    continue
  fi
  probe_list "$WORK/todo" "$WORK/res.$name"
  guard
  NAMES+=("$name")
  ARGS[$name]=$args
  while read -r d ok; do
    [ "$ok" = 1 ] && ASSIGN[$d]=$name
  done <"$WORK/res.$name"
  echo "  $name: подошла для $(awk '$2==1' "$WORK/res.$name" | wc -l) из $(wc -l <"$WORK/todo")"
  awk '$2==0{print $1}' "$WORK/res.$name" >"$WORK/todo"
done
stop_nfqws
[ "${#NAMES[@]}" -gt 0 ] || { echo "ни одна стратегия не запустилась" >&2; exit 1; }

# Раскладка. Для каждого домена:
#   * открыт без обхода               -> direct (zapret его не трогает);
#   * закрыт, есть рабочая стратегия  -> профиль первой по приоритету;
#   * закрыт, ничего не помогло       -> unknown: нет сайта на этом имени,
#     блокировка по IP или нужна стратегия, которой нет в candidates.txt.
#     Остаётся в профиле первой стратегии, как было до подбора.
for d in "${DOMAINS[@]}"; do
  [ -n "${ASSIGN[$d]:-}" ] || ASSIGN[$d]=unknown
done

group() { for d in "${DOMAINS[@]}"; do [ "${ASSIGN[$d]}" = "$1" ] && echo "$d"; done; true; }

echo
echo "=== итог ==="
for n in "${NAMES[@]}"; do
  c=$(group "$n" | wc -l)
  [ "$c" -gt 0 ] && echo "$n: $c"
done
echo "direct (открыты без обхода, zapret их не трогает): $(group direct | wc -l)"
echo "unknown (не отвечают ни с одной стратегией): $(group unknown | wc -l)"
group unknown | sed 's/^/    /'

# Полная таблица — чтобы было видно, на чём основано решение по каждому домену.
echo
echo "=== по доменам: домен | без обхода | назначено ==="
for d in "${DOMAINS[@]}"; do
  base=заблокирован
  grep -qx "$d 1" "$WORK/res.none" && base=открыт
  printf '%-44s %-13s %s\n' "$d" "$base" "${ASSIGN[$d]}"
done

# JSON пишем сами: у root в PATH может не быть jq. В именах доменов и
# аргументах nfqws2 нет символов, требующих экранирования, кроме \ и ".
json_list() {
  local first=1 x
  printf '['
  for x in "$@"; do
    [ "$first" = 1 ] || printf ', '
    first=0
    x=${x//\\/\\\\}
    printf '"%s"' "${x//\"/\\\"}"
  done
  printf ']'
}

first=${NAMES[0]}
declare -A PHOSTS
USED=()
for n in "${NAMES[@]}"; do
  hosts=$(group "$n")
  [ "$n" = "$first" ] && hosts=$(printf '%s\n%s\n' "$hosts" "$(group unknown)")
  hosts=$(sed '/^$/d' <<<"$hosts" | sort)
  [ -n "$hosts" ] || continue
  PHOSTS[$n]=$hosts
  USED+=("$n")
done

# nfqws2 берёт первый профиль, в чей список попал хост, а список покрывает и
# поддомены. Если в одном профиле a.b.com, а в другом b.com, раньше должен
# идти профиль с более точным именем: сортируем по числу таких «вложенных».
ORDER=$(for n in "${USED[@]}"; do
  c=0
  for h in ${PHOSTS[$n]}; do
    for m in "${USED[@]}"; do
      [ "$m" = "$n" ] && continue
      for o in ${PHOSTS[$m]}; do
        [[ $h == *".$o" ]] && c=$((c + 1))
      done
    done
  done
  echo "$c $n"
done | sort -s -k1,1nr | awk '{print $2}')

# Контроль: поднимаем все профили разом, как это сделает служба, и проверяем
# ещё раз. По отдельности стратегии уже проверены, здесь ловим ошибки сборки:
# домен попал под чужой профиль, списки пересеклись и т. п.
: >"$WORK/final.profiles"
opt=--name
for n in $ORDER; do
  tr ' ' '\n' <<<"${PHOSTS[$n]}" >"$WORK/hosts.$n"
  profile_lines "$opt" "$n" "${ARGS[$n]}" "$WORK/hosts.$n" >>"$WORK/final.profiles"
  opt=--new
done
for d in "${DOMAINS[@]}"; do
  case "${ASSIGN[$d]}" in direct | unknown) ;; *) echo "$d" ;; esac
done >"$WORK/final.todo"
start_nfqws "@$WORK/final.profiles" || { echo "nfqws2 не запустился с итоговым набором профилей:" >&2; tail -5 "$WORK/nfqws.log" >&2; exit 1; }
probe_list "$WORK/final.todo" "$WORK/res.final"
stop_nfqws
guard
echo
echo "=== контроль итогового набора: открывается $(awk '$2==1' "$WORK/res.final" | wc -l) из $(wc -l <"$WORK/final.todo") ==="
awk '$2==0{print "    НЕ ПРОШЁЛ: " $1}' "$WORK/res.final"

[ "$DRY" = 1 ] && { echo; echo "--dry-run: $OUT не изменён"; exit 0; }

{
  echo '{'
  echo "  \"generated\": \"$(date +%F)\","
  echo '  "note": "Сгенерировано scripts/zapret2-tune.sh (just zapret-tune). Руками не править.",'
  echo "  \"youtube_cache\": \"${PROBE[googlevideo.com]:-}\","
  echo '  "profiles": ['
  sep=
  for n in $ORDER; do
    printf '%s    {\n      "name": "%s",\n      "desync": ' "$sep" "$n"
    # shellcheck disable=SC2086
    json_list ${ARGS[$n]}
    printf ',\n      "hosts": '
    # shellcheck disable=SC2086
    json_list ${PHOSTS[$n]}
    printf '\n    }'
    sep=$',\n'
  done
  printf '\n  ]\n}\n'
} >"$WORK/profiles.json"
install -m 644 -o "$(stat -c %u "$HOSTS")" -g "$(stat -c %g "$HOSTS")" "$WORK/profiles.json" "$OUT"
echo
echo "записал $OUT — применить: just switch"
