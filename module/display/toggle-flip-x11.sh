#!/usr/bin/env bash
set -x  # debug режим
exec > /tmp/toggle-flip.log 2>&1  # логи в файл

STATE_FILE="/tmp/screen_rotation_state"
DOUBLE_CLICK_FILE="/tmp/power_double_click"
LOCK_FILE="/tmp/power_button_lock"
DOUBLE_CLICK_TIMEOUT_MS=250

echo "=== Запуск скрипта ==="
echo "Время: $(date)"
echo "PID: $$"
echo "USER: $USER"
echo "Исходный DISPLAY: $DISPLAY"
echo "Исходный XAUTHORITY: $XAUTHORITY"

# Находим правильный DISPLAY и XAUTHORITY для текущей GNOME сессии
# Ищем процесс gnome-shell текущего пользователя
GNOME_SHELL_PID=$(pgrep -u $(id -u) gnome-shell | head -1)

if [ -z "$GNOME_SHELL_PID" ]; then
  echo "ОШИБКА: Не найден процесс gnome-shell"
  exit 1
fi

echo "Найден gnome-shell PID: $GNOME_SHELL_PID"

# Получаем переменные окружения из процесса gnome-shell
export DISPLAY=$(grep -z ^DISPLAY= /proc/$GNOME_SHELL_PID/environ | cut -d= -f2- | tr -d '\0')
export XAUTHORITY=$(grep -z ^XAUTHORITY= /proc/$GNOME_SHELL_PID/environ | cut -d= -f2- | tr -d '\0')
export DBUS_SESSION_BUS_ADDRESS=$(grep -z ^DBUS_SESSION_BUS_ADDRESS= /proc/$GNOME_SHELL_PID/environ | cut -d= -f2- | tr -d '\0')

echo "Установлен DISPLAY: $DISPLAY"
echo "Установлен XAUTHORITY: $XAUTHORITY"
echo "Установлен DBUS_SESSION_BUS_ADDRESS: $DBUS_SESSION_BUS_ADDRESS"

# Проверяем что можем подключиться к D-Bus
if ! gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.gnome.Mutter.DisplayConfig.GetCurrentState >/dev/null 2>&1; then
  echo "ОШИБКА: Не удается подключиться к D-Bus сессии"
  exit 1
fi

echo "D-Bus соединение успешно"

# Функция получения времени в миллисекундах
get_time_ms() {
  if command -v date >/dev/null 2>&1; then
    date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000))
  else
    echo $(($(date +%s) * 1000))
  fi
}

# Получить текущий serial от Mutter DisplayConfig
get_serial() {
  gdbus call --session \
    --dest org.gnome.Mutter.DisplayConfig \
    --object-path /org/gnome/Mutter/DisplayConfig \
    --method org.gnome.Mutter.DisplayConfig.GetCurrentState | \
    awk '{print $2}' | tr -d ','
}

# Применить поворот через gdbus
apply_rotation() {
  local rotation=$1  # 0=normal, 1=left, 2=inverted, 3=right
  local serial=$(get_serial)

  echo "Применяем поворот $rotation (serial: $serial)"

  gdbus call --session \
    --dest org.gnome.Mutter.DisplayConfig \
    --object-path /org/gnome/Mutter/DisplayConfig \
    --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
    $serial 1 \
    "[(0, 0, 1.25, uint32 $rotation, true, [('eDP-1', '2880x1800@60.000', {})])]" \
    "{}"

  local result=$?
  echo "Результат gdbus: $result"
  return $result
}

# Блокировка основной клавиатуры
block_keyboard() {
  echo "Блокируем клавиатуру..."
  MAIN_KB_ID=$(xinput list | grep "AT Translated Set 2 keyboard" | grep -o 'id=[0-9]*' | cut -d= -f2)
  if [[ -n "$MAIN_KB_ID" ]]; then
    xinput disable "$MAIN_KB_ID" 2>/dev/null
    echo "$MAIN_KB_ID" > /tmp/blocked_keyboard_id
    echo "Клавиатура заблокирована (ID: $MAIN_KB_ID)"
  else
    echo "Не удалось найти основную клавиатуру для блокировки"
  fi
}

# Разблокировка клавиатуры
unblock_keyboard() {
  echo "Разблокируем клавиатуру..."
  if [ -f /tmp/blocked_keyboard_id ]; then
    KB_ID=$(cat /tmp/blocked_keyboard_id)
    xinput enable "$KB_ID" 2>/dev/null
    xset r on 2>/dev/null || true
    xinput set-prop "$KB_ID" "libinput Repeat" 1 2>/dev/null || true
    rm /tmp/blocked_keyboard_id
    echo "Клавиатура разблокирована (ID: $KB_ID)"
  else
    echo "Нет информации о заблокированной клавиатуре"
  fi
}

# Применение матрицы трансформации для устройств ввода
apply_input_transform() {
  local matrix="$1"
  echo "Применяем трансформацию: $matrix"

  xinput list --short 2>/dev/null | grep -E "slave.*pointer|floating.*pointer" | while IFS= read -r line; do
    device_id=$(echo "$line" | grep -o 'id=[0-9]*' | cut -d= -f2)
    device_name=$(echo "$line" | sed 's/.*↳[[:space:]]*//' | sed 's/[[:space:]]*id=.*//')
    if [[ -n "$device_id" ]]; then
      echo "  Настраиваем устройство: $device_name (ID: $device_id)"
      xinput set-prop "$device_id" "Coordinate Transformation Matrix" $matrix 2>/dev/null || true
    fi
  done
}

# Выполнение стандартного поворота экрана
perform_standard_rotation() {
  echo "=== perform_standard_rotation ==="

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
        ROTATION_CODE=2
        MATRIX="-1 0 1 0 -1 1 0 0 1"
        MESSAGE="Экран повернут на 180°"
        ;;
      "inverted")
        NEXT_ROTATION="normal"
        ROTATION_CODE=0
        MATRIX="1 0 0 0 1 0 0 0 1"
        MESSAGE="Экран возвращен в нормальное положение"
        ;;
      *)
        NEXT_ROTATION="normal"
        ROTATION_CODE=0
        MATRIX="1 0 0 0 1 0 0 0 1"
        MESSAGE="Экран сброшен в нормальное положение"
        ;;
    esac

    echo "Поворачиваем экран ($CURRENT_ROTATION -> $NEXT_ROTATION, код: $ROTATION_CODE)"

    # Поворачиваем через gdbus
    if apply_rotation $ROTATION_CODE; then
      echo "Поворот успешно применен"
    else
      echo "ОШИБКА: не удалось применить поворот"
    fi

    # Небольшая задержка для применения
    sleep 0.3

    # Применяем трансформацию для устройств ввода
    apply_input_transform "$MATRIX"

    # Управляем клавиатурой
    if [ "$NEXT_ROTATION" = "normal" ]; then
      unblock_keyboard
    else
      block_keyboard
    fi

    echo "${NEXT_ROTATION}|rotation" > "$STATE_FILE"
  fi

  echo "=== Результат ==="
  echo "$MESSAGE"
  echo "================="
}

# Выполнение блокировки клавиатуры (двойное нажатие)
perform_keyboard_lock() {
  echo "=== perform_keyboard_lock ==="

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
    perform_keyboard_lock
    flock -u 200
    exit 0
  else
    echo "Предыдущее нажатие не подходит (${TIME_DIFF_MS}мс)"
    if [ $TIME_DIFF_MS -lt 0 ]; then
      echo "Отрицательная разница - возможно проблема с временем"
    fi
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
    echo "Файл изменился (было: $CURRENT_TIME_MS, стало: $SAVED_TIME_MS) - обработано другим процессом"
  fi
else
  echo "Файл исчез - было двойное нажатие, обработанное другим процессом"
fi

flock -u 200

find /tmp -name "power_double_click" -mmin +5 -delete 2>/dev/null || true
find /tmp -name "power_button_lock" -mmin +5 -delete 2>/dev/null || true

echo "=== Завершение скрипта ==="
