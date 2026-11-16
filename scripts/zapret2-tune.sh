#!/usr/bin/env bash
# Подбор стратегий zapret2 под текущую сеть. Методика — docs/zapret2-tuning.md.
#
# Для каждого домена из module/zapret2/hosts.txt решает, нужен ли обход и какой:
#   direct   — открывается без обхода, zapret его не трогает;
#   <имя>    — закрыт, открывается со стратегией <имя> из candidates.txt;
#   unknown  — закрыт, ни одна стратегия не помогла (или на tcp/443 никого нет);
#   flaky    — мерцает сам по себе, решение не воспроизводится; zapret не трогает.
# Решения хранятся в module/zapret2/tune-state.txt, из них собирается
# module/zapret2/profiles.json для module/zapret2.nix. Применяется `just switch`.
#
# Запуск: just zapret-tune            обычный: перепроверить прошлые решения и
#                                     подобрать заново только то, что сломалось
#         just zapret-tune --full     с нуля, включая unknown
#         just zapret-tune --dry-run  только отчёт, файлы не трогать
#         just zapret-check           без root: что не открывается прямо сейчас
#
# На время подбора боевая служба остановлена, в конце возвращается как была.
# `just switch` во время подбора не запускать: он поднимет службу, и замеры
# смешаются (скрипт это заметит и прервётся).
set -euo pipefail

DRY=0
CHECK=0
FULL=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --check) CHECK=1 ;;
    --full) FULL=1 ;;
    *) echo "неизвестный аргумент: $a" >&2; exit 2 ;;
  esac
done

REPO=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
HOSTS=$REPO/module/zapret2/hosts.txt
CANDIDATES=$REPO/module/zapret2/candidates.txt
PROBES=$REPO/module/zapret2/probe-hosts.txt
STATE=$REPO/module/zapret2/tune-state.txt
OUT=$REPO/module/zapret2/profiles.json

# Параллельность первого прохода. Не задирать: под параллельной нагрузкой сеть
# даёт ложные отказы на открытых сайтах. Проверено на этой сети:
#   32 потока — «упали» Discord и YouTube, которые через пять минут открывались
#               6 раз из 6;
#   8 потоков — два прогона подряд разложили домены по-разному;
#   6 потоков, одна параллельная перепроверка — 27 открытых сайтов (debian.org,
#               trello.com, githubusercontent.com) записаны в закрытые, контроль
#               итогового набора провалил 22 из 71.
# Последовательные запросы при этом стабильны. Поэтому первый проход идёт
# небольшой пачкой, а всё, что в нём упало, перепроверяется по одному: открытый
# сайт отвечает за доли секунды, так что точность почти ничего не стоит.
JOBS=${JOBS:-3}
# Сколько раз перепроверять упавший домен (по одному), прежде чем считать отказ настоящим.
RETRIES=${RETRIES:-1}
# Рабочий handshake укладывается в секунду; больше ждать — только копить таймауты.
MAX_TIME=${MAX_TIME:-3}
# Отдельные очередь и таблица, чтобы не делить их с боевой службой.
QNUM=${QNUM:-201}
TABLE=zapret2tune

# Проверяем прямой доступ: прокси из окружения дал бы ложный «работает».
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY

T0=$SECONDS
stamp() { printf '[%2d:%02d] ' $(((SECONDS - T0) / 60)) $(((SECONDS - T0) % 60)); }
say() { stamp; echo "$*"; }

# --- проверки -------------------------------------------------------------

# Какой из хостов домена отвечает на tcp/443. Дальше TLS проверяется только на
# нём: второй хост — это второй таймаут на каждый отказ. Если не отвечает ни
# один, сайта на этом имени нет или он закрыт по IP: стратегия не поможет.
pick_host() { # $1 = домен, $2.. = хосты -> «домен хост» или «домен -»
  local d=$1 h
  shift
  for h in "$@"; do
    # 4 с: сюда входит и DNS, а он под пачкой запросов отвечает небыстро.
    if timeout 4 bash -c "exec 3<>/dev/tcp/$h/443" 2>/dev/null; then echo "$d $h"; return; fi
  done
  echo "$d -"
}
# TLS считается пройденным, если curl дошёл до конца handshake (time_appconnect
# > 0). Код ответа не важен: 403/404 от сервера — это уже «не заблокировано».
probe_one() { # $1 = домен, $2 = хост -> «домен 0|1»
  local t
  # -I (HEAD): нужен только handshake, тело страницы качать незачем — на
  # открытых сайтах это сокращало проход втрое.
  t=$(curl -4 -sI -o /dev/null --noproxy '*' --connect-timeout 2 --max-time "$MAX_TIME" \
    -w '%{time_appconnect}' "https://$2/" 2>/dev/null || true)
  if [ -n "$t" ] && [ "$t" != "0.000000" ]; then echo "$1 1"; else echo "$1 0"; fi
}
export -f pick_host probe_one
export MAX_TIME

# probe_list <файл «домен хост»> <файл результата «домен 0|1»>
# Упавшие перепроверяются после паузы и по одному: разовый сбой или шум от
# параллельных запросов не должен менять решение.
probe_list() {
  local try
  xargs -r -P "$JOBS" -L1 bash -c 'probe_one "$@"' _ <"$1" | sort >"$2"
  for try in $(seq "$RETRIES"); do
    failed "$2" >"$2.failed"
    only "$2.failed" <"$1" >"$2.retry"
    [ -s "$2.retry" ] || break
    sleep 2
    xargs -r -P 1 -L1 bash -c 'probe_one "$@"' _ <"$2.retry" | sort >"$2.b"
    { without "$2.b" <"$2"; cat "$2.b"; } | sort >"$2.m"
    mv "$2.m" "$2"
  done
}
# Фильтры по списку из файла. Не писать это через awk 'NR==FNR{...}': на
# пустом первом файле условие верно и для второго, и фильтр молча выбрасывает
# всё (так однажды все домены со стратегиями ушли в unknown).
without() { # $1 = файл со списком доменов; stdin «домен ...» -> строки, чьих доменов в списке нет
  awk -v f="$1" 'BEGIN{while((getline l < f) > 0){split(l, a, " "); x[a[1]]}} !($1 in x)'
}
only() { # то же, но оставить только домены из списка
  awk -v f="$1" 'BEGIN{while((getline l < f) > 0){split(l, a, " "); x[a[1]]}} ($1 in x)'
}
passed() { awk '$2==1{print $1}' "$1"; }
failed() { awk '$2==0{print $1}' "$1"; }
# targets <файл доменов> -> «домен хост» для тех, у кого хост выбран
targets() { awk '$2!="-"' "$WORK/hostmap" | only "$1"; }

# --- входные данные -------------------------------------------------------

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

# Прошлые решения: «домен группа». С --full не читаются.
declare -A PREV
PREV_GGC=
if [ "$FULL" = 0 ] && [ -r "$STATE" ]; then
  PREV_GGC=$(sed -n 's/^# youtube_cache //p' "$STATE" | head -1)
  while read -r d g; do
    [ -n "$g" ] && PREV[$d]=$g
  done < <(grep -vE '^\s*(#|$)' "$STATE")
fi

# Видео YouTube отдаёт кэш Google у провайдера (rrN---sn-XXXX.googlevideo.com),
# и блокируют его иначе, чем youtube.com. Имя своего кэша узнаём у Google:
# report_mapping отдаёт код площадки, он переводится в sn-имя заменой букв.
detect_ggc() {
  local raw code
  raw=$(curl -4 -s --noproxy '*' --max-time 4 'https://redirector.googlevideo.com/report_mapping?di=no' 2>/dev/null || true)
  code=$(sed -n 's/.*=>[ ]*\([^ (:)]*\).*/\1/p' <<<"$raw" | head -1)
  [ -n "$code" ] || return 1
  echo "rr1---sn-$(tr 'uzpkfa50vqlgb61wrmhc72xsnid83ytoje94' '0123456789abcdefghijklmnopqrstuvwxyz' <<<"$code").googlevideo.com"
}

WORK=$(mktemp -d)
# nfqws2 после старта сбрасывает root и должен дочитаться до своих списков.
chmod 755 "$WORK"
trap 'rm -rf "$WORK"' EXIT
printf '%s\n' "${DOMAINS[@]}" >"$WORK/all"

make_hostmap() { # $1 = файл доменов -> $WORK/hostmap («домен хост|-»)
  local d
  hosts_of() { while read -r d; do echo "$d ${PROBE[$d]:-$d www.$d}"; done; }
  hosts_of <"$1" | xargs -r -P 12 -L1 bash -c 'pick_host "$@"' _ | sort >"$WORK/hostmap.a"
  # Неответившие — ещё раз и по одному: однажды пачка запросов (холодный кэш
  # DNS) записала в «мёртвые» 107 живых доменов из 196.
  awk '$2=="-"{print $1}' "$WORK/hostmap.a" >"$WORK/hostmap.retry"
  hosts_of <"$WORK/hostmap.retry" | xargs -r -P 2 -L1 bash -c 'pick_host "$@"' _ | sort >"$WORK/hostmap.b"
  { without "$WORK/hostmap.b" <"$WORK/hostmap.a"; cat "$WORK/hostmap.b"; } | sort >"$WORK/hostmap"
}

if [ "$CHECK" = 1 ]; then
  systemctl is-active -q zapret2 && echo "zapret2: включён" || echo "zapret2: ВЫКЛЮЧЕН (проверка без обхода)"
  if [ -z "${PROBE[googlevideo.com]:-}" ]; then
    PROBE[googlevideo.com]=$(detect_ggc || echo "${PREV_GGC:-googlevideo.com}")
    echo "кэш YouTube: ${PROBE[googlevideo.com]}"
  fi
  make_hostmap "$WORK/all"
  targets "$WORK/all" >"$WORK/t.check"
  probe_list "$WORK/t.check" "$WORK/res.check"
  echo "открывается напрямую: $(passed "$WORK/res.check" | wc -l) из ${#DOMAINS[@]}"
  echo "не проходит TLS:"
  failed "$WORK/res.check" | while read -r d; do printf '    %-40s %s\n' "$d" "${PREV[$d]:-}"; done
  echo "не отвечают на tcp/443 (сайта нет или блок по IP): $(awk '$2=="-"' "$WORK/hostmap" | wc -l)"
  exit 0
fi

[ "$(id -u)" = 0 ] || { echo "нужен root: sudo $0 $*" >&2; exit 1; }

mapfile -t CAND_LINES < <(grep -vE '^\s*(#|$)' "$CANDIDATES")
[ "${#CAND_LINES[@]}" -gt 0 ] || { echo "пустой $CANDIDATES" >&2; exit 1; }
NAMES=()
declare -A ARGS
for line in "${CAND_LINES[@]}"; do
  n=$(sed 's/ *|.*//' <<<"$line")
  NAMES+=("$n")
  ARGS[$n]=$(sed 's/^[^|]*| *//' <<<"$line")
done

# --- nfqws2 и nft: те же, что у службы -------------------------------------

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
  echo "zapret2.service запустили во время подбора — результаты недостоверны, прерываюсь." >&2
  WAS_ACTIVE=1
  exit 1
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
# Все профили разом, как их соберёт служба. $1 = файл «домен группа».
# nfqws2 берёт первый профиль, в чей список попал хост, а список покрывает и
# поддомены. Если в одном профиле a.b.com, а в другом b.com, раньше должен идти
# профиль с более точным именем: сортируем по числу таких «вложенных».
profile_order() { # $1 = файл «домен группа» -> имена профилей по порядку
  awk -v names="${NAMES[*]}" '
    BEGIN { n = split(names, N, " "); for (i = 1; i <= n; i++) known[N[i]] = i }
    ($2 in known) { g[$1] = $2; used[$2] = 1 }
    END {
      for (h in g) for (o in g) if (g[h] != g[o] && length(h) > length(o) + 1 &&
        substr(h, length(h) - length(o)) == "." o) sub_[g[h]]++
      for (i = 1; i <= n; i++) if (N[i] in used) printf "%d %d %s\n", -sub_[N[i]], i, N[i]
    }' "$1" | sort -k1,1n -k2,2n | awk '{print $3}'
}
start_combined() { # $1 = файл «домен группа»
  local opt=--name n
  : >"$WORK/combined"
  for n in $(profile_order "$1"); do
    awk -v g="$n" '$2==g{print $1}' "$1" | sort >"$WORK/hosts.$n"
    profile_lines "$opt" "$n" "${ARGS[$n]}" "$WORK/hosts.$n" >>"$WORK/combined"
    opt=--new
  done
  [ -s "$WORK/combined" ] || return 2
  start_nfqws "@$WORK/combined"
}

# --- что проверять ---------------------------------------------------------

# Прошлое решение по домену берём как отправную точку и только перепроверяем:
#   стратегия -> всё ещё открывается с ней? (один общий запуск на всех)
#   direct    -> всё ещё открывается без обхода?
#   unknown, flaky -> пропускаем: это самые дорогие домены (каждая попытка — полный
#                таймаут на каждой стратегии), а шанс, что они ожили, мал.
#                Перепроверяются только с --full.
# Подбор по всем стратегиям идёт лишь для новых доменов и для тех, чьё прошлое
# решение перестало работать.
: >"$WORK/keep_strategy" # «домен группа» — перепроверить под прошлой стратегией
: >"$WORK/keep_direct"   # перепроверить без обхода
: >"$WORK/fresh"         # решать с нуля
: >"$WORK/skipped"
for d in "${DOMAINS[@]}"; do
  g=${PREV[$d]:-}
  if [ -z "$g" ]; then
    echo "$d" >>"$WORK/fresh"
  elif [ "$g" = direct ]; then
    echo "$d" >>"$WORK/keep_direct"
  elif [ "$g" = unknown ] || [ "$g" = flaky ]; then
    echo "$d" >>"$WORK/skipped"
  elif [ -n "${ARGS[$g]:-}" ]; then
    echo "$d $g" >>"$WORK/keep_strategy"
  else
    echo "$d" >>"$WORK/fresh" # стратегию убрали из candidates.txt
  fi
done
say "доменов: ${#DOMAINS[@]}; перепроверить под стратегией: $(wc -l <"$WORK/keep_strategy"), без обхода: $(wc -l <"$WORK/keep_direct"), с нуля: $(wc -l <"$WORK/fresh"), пропущено unknown/flaky: $(wc -l <"$WORK/skipped")"

# Кэш YouTube. Без обхода redirector недоступен, поэтому спрашиваем под
# стратегией: сначала под той, что уже работала для googlevideo.com.
if [ -z "${PROBE[googlevideo.com]:-}" ]; then
  order=("${NAMES[@]}")
  pg=${PREV[googlevideo.com]:-}
  [ -n "$pg" ] && [ -n "${ARGS[$pg]:-}" ] && order=("$pg" "${NAMES[@]}")
  for n in "${order[@]}"; do
    start_nfqws "${ARGS[$n]}" || continue
    if ggc=$(detect_ggc); then PROBE[googlevideo.com]=$ggc; break; fi
  done
  stop_nfqws
  if [ -z "${PROBE[googlevideo.com]:-}" ] && [ -n "$PREV_GGC" ]; then
    PROBE[googlevideo.com]=$PREV_GGC
    say "кэш YouTube не определился, беру прошлый: $PREV_GGC"
  elif [ -n "${PROBE[googlevideo.com]:-}" ]; then
    say "кэш YouTube: ${PROBE[googlevideo.com]}"
  else
    echo "ВНИМАНИЕ: не узнал кэш YouTube; googlevideo.com будет проверен неточно." >&2
    echo "  Задай узел вручную в $PROBES: googlevideo.com rrN---sn-XXXX.googlevideo.com" >&2
  fi
fi

# Живой хост для каждого домена, который будем проверять.
without "$WORK/skipped" <"$WORK/all" >"$WORK/scope"
make_hostmap "$WORK/scope"
awk '$2=="-"{print $1}' "$WORK/hostmap" >"$WORK/dead"
say "не отвечают на tcp/443: $(wc -l <"$WORK/dead") (в проверках не участвуют)"

declare -A ASSIGN
: >"$WORK/todo" # кому подбирать стратегию
CHANGED=0

# Мёртвые: прошлое решение не трогаем (сбой сети не должен его стирать),
# новые получают unknown.
while read -r d; do
  if [ -n "${PREV[$d]:-}" ]; then ASSIGN[$d]=${PREV[$d]}; else ASSIGN[$d]=unknown; fi
done <"$WORK/dead"
while read -r d; do ASSIGN[$d]=${PREV[$d]}; done <"$WORK/skipped"

# 1. Без обхода: прошлые direct и новые домены.
cat "$WORK/keep_direct" "$WORK/fresh" | without "$WORK/dead" >"$WORK/d.base"
targets "$WORK/d.base" >"$WORK/t.base"
stop_nfqws
probe_list "$WORK/t.base" "$WORK/res.base"
guard
while read -r d; do ASSIGN[$d]=direct; done < <(passed "$WORK/res.base")
failed "$WORK/res.base" >>"$WORK/todo"
say "без обхода: открыты $(passed "$WORK/res.base" | wc -l) из $(wc -l <"$WORK/t.base")"

# 2. Прошлые стратегии: все профили разом, один запуск.
without "$WORK/dead" <"$WORK/keep_strategy" >"$WORK/ks"
if [ -s "$WORK/ks" ]; then
  if start_combined "$WORK/ks"; then
    targets <(awk '{print $1}' "$WORK/ks") >"$WORK/t.keep"
    probe_list "$WORK/t.keep" "$WORK/res.keep"
    stop_nfqws
    guard
    while read -r d; do ASSIGN[$d]=${PREV[$d]}; done < <(passed "$WORK/res.keep")
    failed "$WORK/res.keep" >>"$WORK/todo"
    say "прошлые стратегии: работают $(passed "$WORK/res.keep" | wc -l) из $(wc -l <"$WORK/t.keep")"
  else
    echo "nfqws2 не запустился с прошлым набором профилей, подбираю их заново:" >&2
    tail -3 "$WORK/nfqws.log" >&2
    awk '{print $1}' "$WORK/ks" >>"$WORK/todo"
  fi
fi

# Перед подбором — второй взгляд без обхода на всех кандидатов. Подбор — самая
# дорогая часть (домен × все стратегии × таймаут), а большинство попавших сюда
# из direct — мерцающие сайты, которые через полминуты снова открыты. Их сразу
# в flaky, без прогона по стратегиям.
if [ -s "$WORK/todo" ]; then
  stop_nfqws
  targets "$WORK/todo" >"$WORK/t.again"
  probe_list "$WORK/t.again" "$WORK/res.again"
  guard
  while read -r d; do ASSIGN[$d]=flaky; done < <(passed "$WORK/res.again")
  failed "$WORK/res.again" >"$WORK/todo"
  say "второй взгляд без обхода: открылись сами $(passed "$WORK/res.again" | wc -l) (flaky), закрыты $(wc -l <"$WORK/todo")"
fi

# 3. Подбор: каждая следующая стратегия проверяет только домены, которым ещё
# не нашлось рабочей. Домен получает первую подошедшую по списку.
: >"$WORK/new" # домены, получившие стратегию в этом прогоне
if [ -s "$WORK/todo" ]; then
  say "подбираю стратегию для $(wc -l <"$WORK/todo") доменов"
  for n in "${NAMES[@]}"; do
    [ -s "$WORK/todo" ] || break
    if ! start_nfqws "${ARGS[$n]}"; then
      echo "  $n: nfqws2 не запустился с этими аргументами, пропускаю:" >&2
      tail -3 "$WORK/nfqws.log" >&2
      continue
    fi
    targets "$WORK/todo" >"$WORK/t.$n"
    probe_list "$WORK/t.$n" "$WORK/res.$n"
    guard
    while read -r d; do ASSIGN[$d]=$n; done < <(passed "$WORK/res.$n")
    passed "$WORK/res.$n" >>"$WORK/new"
    say "  $n: подошла для $(passed "$WORK/res.$n" | wc -l) из $(wc -l <"$WORK/t.$n")"
    failed "$WORK/res.$n" >"$WORK/todo"
  done
  stop_nfqws
  while read -r d; do ASSIGN[$d]=unknown; done <"$WORK/todo"
fi
for d in "${DOMAINS[@]}"; do
  [ -n "${ASSIGN[$d]:-}" ] || ASSIGN[$d]=unknown
done

# 4. Подтверждение новых решений. Часть сайтов на этой сети мерцает сама по
# себе: trello.com, debian.org, gnome.org (Fastly, CloudFront) за несколько
# секунд переходят из «открыт» в «закрыт» и обратно без всякого обхода. Такой
# домен случайно попадает в закрытые, потом случайно «чинится» очередной
# стратегией — и каждый прогон раскладывает его по-новому. Поэтому решение
# «закрыт, лечится стратегией X» принимается только если оно повторилось:
#   а) под всеми профилями разом (как в службе) домен открывается снова;
#   б) без обхода, спустя время, он по-прежнему закрыт.
# Не подтвердилось -> flaky: zapret его не трогает (помочь не может, навредить
# может), в следующих запусках он пропускается, как unknown.
dump_assign() { for d in "${DOMAINS[@]}"; do echo "$d ${ASSIGN[$d]}"; done; }
if [ -s "$WORK/new" ]; then
  dump_assign | without "$WORK/dead" >"$WORK/final"
  if start_combined "$WORK/final"; then
    targets "$WORK/new" >"$WORK/t.confirm"
    probe_list "$WORK/t.confirm" "$WORK/res.confirm"
    stop_nfqws
    guard
    while read -r d; do ASSIGN[$d]=flaky; done < <(failed "$WORK/res.confirm")
    say "подтверждение под итоговым набором: $(passed "$WORK/res.confirm" | wc -l) из $(wc -l <"$WORK/t.confirm")"
    passed "$WORK/res.confirm" >"$WORK/new2"
  else
    echo "nfqws2 не запустился с итоговым набором профилей:" >&2
    tail -5 "$WORK/nfqws.log" >&2
    exit 1
  fi
  if [ -s "$WORK/new2" ]; then
    targets "$WORK/new2" >"$WORK/t.base2"
    probe_list "$WORK/t.base2" "$WORK/res.base2"
    guard
    while read -r d; do ASSIGN[$d]=flaky; done < <(passed "$WORK/res.base2")
    say "повтор без обхода: всё ещё закрыты $(failed "$WORK/res.base2" | wc -l) из $(wc -l <"$WORK/t.base2")"
  fi
fi

CHANGED=0
for d in "${DOMAINS[@]}"; do
  [ "${ASSIGN[$d]}" = "${PREV[$d]:-}" ] || CHANGED=$((CHANGED + 1))
done
dump_assign >"$WORK/assign"

# --- отчёт -----------------------------------------------------------------

echo
echo "=== итог ==="
awk '{c[$2]++} END{for(k in c) printf "  %-24s %d\n", k, c[k]}' "$WORK/assign" | sort
if [ "${#PREV[@]}" -gt 0 ]; then
  echo "изменилось решений: $CHANGED"
  for d in "${DOMAINS[@]}"; do
    [ "${ASSIGN[$d]}" = "${PREV[$d]:-}" ] || printf '    %-40s %s -> %s\n' "$d" "${PREV[$d]:-новый}" "${ASSIGN[$d]}"
  done
fi
[ -s "$WORK/skipped" ] && echo "unknown и flaky не перепроверялись ($(wc -l <"$WORK/skipped")); перепроверить: just zapret-tune --full"

# Предохранитель: если стратегию разом потеряла заметная часть доменов, это
# почти наверняка сбой сети или ошибка в скрипте, а не новая реальность.
lost=0
had=0
for d in "${DOMAINS[@]}"; do
  p=${PREV[$d]:-}
  [ -n "$p" ] && [ -n "${ARGS[$p]:-}" ] || continue
  had=$((had + 1))
  [ -n "${ARGS[${ASSIGN[$d]}]:-}" ] || lost=$((lost + 1))
done
if [ "$had" -ge 8 ] && [ $((lost * 3)) -gt "$had" ]; then
  echo >&2
  echo "Стратегию потеряли $lost доменов из $had — так не бывает от прогона к прогону." >&2
  echo "Файлы НЕ изменены. Проверь сеть и повтори; если это правда — just zapret-tune --full." >&2
  exit 1
fi
[ "$CHANGED" = 0 ] && [ "${#PREV[@]}" -gt 0 ] && { echo; say "все прошлые решения в силе"; }

[ "$DRY" = 1 ] && { echo; say "--dry-run: файлы не изменены"; exit 0; }

# --- запись ----------------------------------------------------------------

owner=$(stat -c %u:%g "$HOSTS")
{
  echo "# Решения scripts/zapret2-tune.sh (just zapret-tune) по каждому домену hosts.txt."
  echo "# Руками не править: файл перезаписывается. Группы: direct — открыт без обхода,"
  echo "# unknown — закрыт и ничего не помогло, flaky — мерцает сам по себе (zapret не трогает),"
  echo "# остальное — имя стратегии из candidates.txt."
  echo "# generated $(date +%F)"
  echo "# youtube_cache ${PROBE[googlevideo.com]:-}"
  cat "$WORK/assign"
} >"$WORK/state"

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
# unknown остаются в профиле первой стратегии, как было до подбора: среди них
# имена, у которых живут только поддомены (ytimg.com, twimg.com).
first=${NAMES[0]}
awk -v f="$first" '{print $1, ($2=="unknown" ? f : $2)}' "$WORK/assign" >"$WORK/assign.json"
{
  echo '{'
  echo "  \"generated\": \"$(date +%F)\","
  echo '  "note": "Сгенерировано scripts/zapret2-tune.sh (just zapret-tune). Руками не править.",'
  echo "  \"youtube_cache\": \"${PROBE[googlevideo.com]:-}\","
  echo '  "profiles": ['
  sep=
  for n in $(profile_order "$WORK/assign.json"); do
    printf '%s    {\n      "name": "%s",\n      "desync": ' "$sep" "$n"
    # shellcheck disable=SC2086
    json_list ${ARGS[$n]}
    printf ',\n      "hosts": '
    # shellcheck disable=SC2046
    json_list $(awk -v g="$n" '$2==g{print $1}' "$WORK/assign.json" | sort)
    printf '\n    }'
    sep=$',\n'
  done
  printf '\n  ]\n}\n'
} >"$WORK/profiles.json"
install -m 644 -o "${owner%:*}" -g "${owner#*:}" "$WORK/state" "$STATE"
install -m 644 -o "${owner%:*}" -g "${owner#*:}" "$WORK/profiles.json" "$OUT"
echo
say "записал profiles.json и tune-state.txt — применить: just switch"
