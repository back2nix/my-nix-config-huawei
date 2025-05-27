#!/usr/bin/env bash

if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

if [ -z "$WAYLAND_DISPLAY" ]; then
    export WAYLAND_DISPLAY="wayland-0"
fi

if [ -z "$DISPLAY" ]; then
    export DISPLAY=":0"
fi

export XDG_CURRENT_DESKTOP="GNOME"
export XDG_SESSION_TYPE="wayland"
export XDG_SESSION_DESKTOP="gnome"

STATE_FILE="/tmp/screen_rotation_state"
DOUBLE_CLICK_FILE="/tmp/power_double_click"
LOCK_FILE="/tmp/power_button_lock"
EVTEST_PIDS_FILE="/tmp/evtest_pids"
KEYBOARD_LOCK_FILE="/tmp/keyboard_locked"
DOUBLE_CLICK_TIMEOUT_MS=250

# Определяем пользователя для работы с gsettings
get_actual_user() {
    ps aux | grep '[g]nome-shell' | head -1 | awk '{print $1}' || \
    ps aux | grep '[g]sd-' | head -1 | awk '{print $1}' || \
    echo "bg"
}

get_user_dbus_address() {
    local user="$1"
    local user_id=$(id -u "$user")

    local dbus_addr=$(ps aux | grep "dbus-daemon.*--session" | grep "$user" | head -1 | \
        sed -n 's/.*--address=\([^ ]*\).*/\1/p')

    if [ -n "$dbus_addr" ]; then
        echo "$dbus_addr"
    else
        echo "unix:path=/run/user/$user_id/bus"
    fi
}

run_as_user() {
    local user="$1"
    shift
    local user_id=$(id -u "$user" 2>/dev/null)
    local dbus_addr=$(get_user_dbus_address "$user")

    if [ -z "$user_id" ]; then
        echo "⚠ Не удалось найти пользователя: $user"
        return 1
    fi

    sudo -u "$user" \
        XDG_RUNTIME_DIR="/run/user/$user_id" \
        WAYLAND_DISPLAY="wayland-0" \
        DISPLAY=":0" \
        XDG_CURRENT_DESKTOP="GNOME" \
        XDG_SESSION_TYPE="wayland" \
        XDG_SESSION_DESKTOP="gnome" \
        DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
        HOME="/home/$user" \
        USER="$user" \
        LOGNAME="$user" \
        "$@"
}

# Проверяем что gnome-randr доступен
if ! command -v gnome-randr >/dev/null 2>&1; then
  echo "Ошибка: gnome-randr не найден. Установите его: pip install gnome-randr"
  exit 1
fi

# Определяем основной дисплей
DISPLAY_NAME=$(gnome-randr query 2>/dev/null | grep -E "^[a-zA-Z]+-[0-9]+" | head -1 | awk '{print $1}')
if [ -z "$DISPLAY_NAME" ]; then
  echo "Не удалось найти подключенный дисплей"
  echo "Доступные дисплеи:"
  gnome-randr query 2>/dev/null | grep -E "^[a-zA-Z]+-[0-9]+"
  exit 1
fi

echo "Используем дисплей: $DISPLAY_NAME"

ACTUAL_USER=$(get_actual_user)
echo "Определен пользователь для gsettings: $ACTUAL_USER"

get_time_ms() {
  if command -v date >/dev/null 2>&1; then
    date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000))
  else
    echo $(($(date +%s) * 1000))
  fi
}

enable_screen_keyboard() {
    echo "Включаем экранную клавиатуру для пользователя $ACTUAL_USER..."
}

disable_screen_keyboard() {
    echo "Выключаем экранную клавиатуру для пользователя $ACTUAL_USER..."
}

# Проверка заблокирована ли клавиатура
is_keyboard_blocked() {
    [ -f "$KEYBOARD_LOCK_FILE" ] && pgrep -f "evtest --grab /dev/input/event1" >/dev/null 2>&1
}

# Блокировка клавиатуры
block_keyboard() {
    echo "Блокируем клавиатуру /dev/input/event1..."

    KEYBOARD_DEVICE="/dev/input/event1"

    # Если уже заблокирована - выходим
    if is_keyboard_blocked; then
        echo "Клавиатура уже заблокирована"
        return 0
    fi

    # Очищаем старые процессы
    pkill -f "evtest --grab /dev/input/event1" 2>/dev/null || true
    rm -f "$EVTEST_PIDS_FILE" "$KEYBOARD_LOCK_FILE"
    sleep 0.2

    # Запускаем evtest в фоне
    evtest --grab "$KEYBOARD_DEVICE" >/dev/null 2>&1 &
    EVTEST_PID=$!

    # Ждём и проверяем что процесс жив
    sleep 0.5
    if ! kill -0 "$EVTEST_PID" 2>/dev/null; then
        echo "⚠ Не удалось запустить evtest"
        return 1
    fi

    # Сохраняем состояние
    echo "$EVTEST_PID" > "$EVTEST_PIDS_FILE"
    touch "$KEYBOARD_LOCK_FILE"
    echo "✓ Заблокирован: $KEYBOARD_DEVICE (PID: $EVTEST_PID)"

    enable_screen_keyboard
    return 0
}

# Разблокировка клавиатуры
unblock_keyboard() {
    echo "Разблокируем клавиатуру..."

    # Убиваем процесс evtest
    if [ -f "$EVTEST_PIDS_FILE" ]; then
        PID=$(cat "$EVTEST_PIDS_FILE" 2>/dev/null)
        if [ -n "$PID" ] && kill "$PID" 2>/dev/null; then
            echo "✓ Завершен процесс evtest PID: $PID"
        fi
    fi

    # Дополнительная очистка
    pkill -f "evtest --grab /dev/input/event1" 2>/dev/null || true

    # Очищаем файлы
    rm -f "$EVTEST_PIDS_FILE" "$KEYBOARD_LOCK_FILE"

    disable_screen_keyboard
    echo "Клавиатура разблокирована"
}

# Выполнение стандартного поворота экрана
perform_standard_rotation() {
    if [ -f "$STATE_FILE" ]; then
        STATE_DATA=$(cat "$STATE_FILE")
        CURRENT_ROTATION=$(echo "$STATE_DATA" | cut -d'|' -f1)
        LAST_ACTION=$(echo "$STATE_DATA" | cut -d'|' -f2)
    else
        CURRENT_ROTATION="normal"
        LAST_ACTION="rotation"
    fi

    echo "Текущее состояние: поворот=$CURRENT_ROTATION, последнее_действие=$LAST_ACTION"

    if [ "$LAST_ACTION" = "keyboard_only" ]; then
        echo "=== Последним была блокировка клавиатуры - разблокируем ==="
        unblock_keyboard
        echo "${CURRENT_ROTATION}|unlock_only" > "$STATE_FILE"
        MESSAGE="Клавиатура разблокирована"
    else
        echo "=== Выполняем: стандартный поворот экрана ==="

        case "$CURRENT_ROTATION" in
            "normal")
                NEXT_ROTATION="inverted"
                MESSAGE="Экран повернут на 180°"
                ;;
            "inverted")
                NEXT_ROTATION="normal"
                MESSAGE="Экран возвращен в нормальное положение"
                ;;
            *)
                NEXT_ROTATION="normal"
                MESSAGE="Экран сброшен в нормальное положение"
                ;;
        esac

        echo "Поворачиваем дисплей: $DISPLAY_NAME ($CURRENT_ROTATION -> $NEXT_ROTATION)"

        if gnome-randr modify --rotate "$NEXT_ROTATION" "$DISPLAY_NAME"; then
            echo "Поворот применен успешно"

            if [ "$NEXT_ROTATION" = "normal" ]; then
                unblock_keyboard
            else
                block_keyboard
            fi

            echo "${NEXT_ROTATION}|rotation" > "$STATE_FILE"
        else
            echo "Ошибка при повороте экрана"
            exit 1
        fi
    fi

    echo "=== Результат ==="
    echo "$MESSAGE"
    echo "================="
}

# Выполнение блокировки клавиатуры (двойное нажатие)
perform_double_click_action() {
    if [ -f "$STATE_FILE" ]; then
        STATE_DATA=$(cat "$STATE_FILE")
        CURRENT_ROTATION=$(echo "$STATE_DATA" | cut -d'|' -f1)
    else
        CURRENT_ROTATION="normal"
    fi

    echo "=== Двойное нажатие - только блокировка клавиатуры ==="

    block_keyboard
    echo "${CURRENT_ROTATION}|keyboard_only" > "$STATE_FILE"
    MESSAGE="Клавиатура заблокирована (двойное нажатие)"

    echo "=== Результат ==="
    echo "$MESSAGE"
    echo "================="
}

# Основная логика
echo "=== Обработка нажатия Power ==="
echo "Время: $(date) ($(get_time_ms)ms)"
echo "PID: $$"

exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "Другой процесс уже обрабатывает нажатие Power, выход"
    exit 0
fi

CURRENT_TIME_MS=$(get_time_ms)

if [ -f "$DOUBLE_CLICK_FILE" ]; then
    LAST_PRESS_MS=$(cat "$DOUBLE_CLICK_FILE")
    TIME_DIFF_MS=$((CURRENT_TIME_MS - LAST_PRESS_MS))

    echo "Найден файл предыдущего нажатия: $LAST_PRESS_MS"
    echo "Текущее время: $CURRENT_TIME_MS"
    echo "Разница: ${TIME_DIFF_MS}мс (лимит: ${DOUBLE_CLICK_TIMEOUT_MS}мс)"

    if [ $TIME_DIFF_MS -le $DOUBLE_CLICK_TIMEOUT_MS ] && [ $TIME_DIFF_MS -ge 0 ]; then
        echo "🔍 Обнаружено ДВОЙНОЕ нажатие (интервал: ${TIME_DIFF_MS}мс)"
        rm "$DOUBLE_CLICK_FILE"
        perform_double_click_action
        flock -u 200
        exit 0
    else
        echo "Предыдущее нажатие не подходит (${TIME_DIFF_MS}мс)"
    fi
fi

echo "$CURRENT_TIME_MS" > "$DOUBLE_CLICK_FILE"
echo "Записано время нажатия: $CURRENT_TIME_MS"

flock -u 200

echo "Ожидаем возможного второго нажатия (${DOUBLE_CLICK_TIMEOUT_MS}мс)..."
if command -v usleep >/dev/null 2>&1; then
    usleep $((DOUBLE_CLICK_TIMEOUT_MS * 1000))
elif python3 -c "import time; time.sleep(0.5)" 2>/dev/null; then
    python3 -c "import time; time.sleep(${DOUBLE_CLICK_TIMEOUT_MS}/1000.0)"
else
    sleep 1
fi

exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "Не удалось захватить блокировку для проверки - возможно обрабатывается двойное нажатие"
    exit 0
fi

if [ -f "$DOUBLE_CLICK_FILE" ]; then
    SAVED_TIME_MS=$(cat "$DOUBLE_CLICK_FILE")

    if [ "$SAVED_TIME_MS" = "$CURRENT_TIME_MS" ]; then
        echo "🔍 Обнаружено ОДИНАРНОЕ нажатие"
        rm "$DOUBLE_CLICK_FILE"
        perform_standard_rotation
    else
        echo "Файл изменился - обработано другим процессом"
    fi
else
    echo "Файл исчез - было двойное нажатие"
fi

flock -u 200

# Очистка старых файлов
find /tmp -name "power_double_click" -mmin +5 -delete 2>/dev/null || true
find /tmp -name "power_button_lock" -mmin +5 -delete 2>/dev/null || true
find /tmp -name "evtest_pids" -mmin +10 -delete 2>/dev/null || true
find /tmp -name "keyboard_locked" -mmin +10 -delete 2>/dev/null || true

echo "=== Завершение скрипта ==="
