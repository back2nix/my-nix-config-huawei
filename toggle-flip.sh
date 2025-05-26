#!/usr/bin/env bash
export DISPLAY=":1"
export XAUTHORITY="/run/user/1000/gdm/Xauthority"
STATE_FILE="/tmp/screen_rotation_state"
DOUBLE_CLICK_FILE="/tmp/power_double_click"
LOCK_FILE="/tmp/power_button_lock"
DOUBLE_CLICK_TIMEOUT_MS=250  # миллисекунды для двойного нажатия

# Проверяем что X доступен
if ! xrandr --query >/dev/null 2>&1; then
  echo "Ошибка: не удается подключиться к X серверу"
  exit 1
fi

# Определяем основной дисплей
DISPLAY_NAME=$(xrandr --query | grep " connected primary" | cut -d" " -f1)
if [ -z "$DISPLAY_NAME" ]; then
  DISPLAY_NAME=$(xrandr --query | grep " connected" | head -1 | cut -d" " -f1)
fi
if [ -z "$DISPLAY_NAME" ]; then
  echo "Не удалось найти подключенный дисплей"
  exit 1
fi

# Функция получения времени в миллисекундах
get_time_ms() {
  if command -v date >/dev/null 2>&1; then
    # Linux/GNU date поддерживает %3N для миллисекунд
    date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000))
  else
    echo $(($(date +%s) * 1000))
  fi
}

# Блокировка основной клавиатуры
block_keyboard() {
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
  if [ -f /tmp/blocked_keyboard_id ]; then
    KB_ID=$(cat /tmp/blocked_keyboard_id)
    xinput enable "$KB_ID" 2>/dev/null
    # Восстанавливаем автоповтор клавиш
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

  # Применяем только к pointer устройствам
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
  # Читаем текущее состояние
  if [ -f "$STATE_FILE" ]; then
    STATE_DATA=$(cat "$STATE_FILE")
    CURRENT_ROTATION=$(echo "$STATE_DATA" | cut -d'|' -f1)
    LAST_ACTION=$(echo "$STATE_DATA" | cut -d'|' -f2)
  else
    CURRENT_ROTATION="normal"
    LAST_ACTION="rotation"
  fi

  echo "Текущее состояние: поворот=$CURRENT_ROTATION, последнее_действие=$LAST_ACTION"

  # Проверяем что было последним действием
  if [ "$LAST_ACTION" = "keyboard_only" ]; then
    echo "=== Последним была блокировка клавиатуры - разблокируем ==="

    unblock_keyboard
    echo "${CURRENT_ROTATION}|unlock_only" > "$STATE_FILE"
    MESSAGE="Клавиатура разблокирована"

  else
    echo "=== Выполняем: стандартный поворот экрана ==="

    # Определяем следующее состояние поворота
    case "$CURRENT_ROTATION" in
      "normal")
        NEXT_ROTATION="inverted"
        ROTATION="inverted"
        MATRIX="-1 0 1 0 -1 1 0 0 1"
        MESSAGE="Экран повернут на 180°"
        ;;
      "inverted")
        NEXT_ROTATION="normal"
        ROTATION="normal"
        MATRIX="1 0 0 0 1 0 0 0 1"
        MESSAGE="Экран возвращен в нормальное положение"
        ;;
      *)
        # Если состояние неизвестно, сбрасываем в normal
        NEXT_ROTATION="normal"
        ROTATION="normal"
        MATRIX="1 0 0 0 1 0 0 0 1"
        MESSAGE="Экран сброшен в нормальное положение"
        ;;
    esac

    echo "Поворачиваем дисплей: $DISPLAY_NAME ($CURRENT_ROTATION -> $NEXT_ROTATION)"

    # Сначала поворачиваем экран
    xrandr --output "$DISPLAY_NAME" --rotate "$ROTATION"

    # Ждем пока поворот применится
    echo "Ожидаем применения поворота..."
    while ! xrandr --query | grep -q "$DISPLAY_NAME.*$ROTATION"; do
      sleep 0.05
    done
    echo "Поворот применен"

    # Затем применяем трансформацию для устройств ввода
    apply_input_transform "$MATRIX"

    # Управляем клавиатурой: разблокируем только в нормальном положении
    if [ "$NEXT_ROTATION" = "normal" ]; then
      unblock_keyboard
    else
      block_keyboard
    fi

    # Сохраняем новое состояние
    echo "${NEXT_ROTATION}|rotation" > "$STATE_FILE"
  fi

  echo "=== Результат ==="
  echo "$MESSAGE"
  echo "================="
}

# Выполнение блокировки клавиатуры (двойное нажатие)
perform_keyboard_lock() {
  # Читаем текущий поворот
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

# Основная логика с блокировкой от race conditions
echo "=== Обработка нажатия Power ==="
echo "Время: $(date) ($(get_time_ms)ms)"
echo "PID: $$"

# Создаем блокировку чтобы избежать одновременной обработки
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  echo "Другой процесс уже обрабатывает нажатие Power, выход"
  exit 0
fi

# Получаем текущее время в миллисекундах
CURRENT_TIME_MS=$(get_time_ms)

# Проверяем есть ли файл двойного нажатия
if [ -f "$DOUBLE_CLICK_FILE" ]; then
  LAST_PRESS_MS=$(cat "$DOUBLE_CLICK_FILE")
  TIME_DIFF_MS=$((CURRENT_TIME_MS - LAST_PRESS_MS))

  echo "Найден файл предыдущего нажатия: $LAST_PRESS_MS"
  echo "Текущее время: $CURRENT_TIME_MS"
  echo "Разница: ${TIME_DIFF_MS}мс (лимит: ${DOUBLE_CLICK_TIMEOUT_MS}мс)"

  if [ $TIME_DIFF_MS -le $DOUBLE_CLICK_TIMEOUT_MS ] && [ $TIME_DIFF_MS -ge 0 ]; then
    echo "🔍 Обнаружено ДВОЙНОЕ нажатие (интервал: ${TIME_DIFF_MS}мс)"
    rm "$DOUBLE_CLICK_FILE"  # Очищаем маркер
    perform_keyboard_lock

    # Освобождаем блокировку и выходим
    flock -u 200
    exit 0
  else
    echo "Предыдущее нажатие не подходит (${TIME_DIFF_MS}мс)"
    if [ $TIME_DIFF_MS -lt 0 ]; then
      echo "Отрицательная разница - возможно проблема с временем"
    fi
  fi
fi

# Записываем время текущего нажатия
echo "$CURRENT_TIME_MS" > "$DOUBLE_CLICK_FILE"
echo "Записано время нажатия: $CURRENT_TIME_MS"

# Освобождаем блокировку перед ожиданием
flock -u 200

# Ждем возможного второго нажатия (используем более точный sleep)
echo "Ожидаем возможного второго нажатия (${DOUBLE_CLICK_TIMEOUT_MS}мс)..."
if command -v usleep >/dev/null 2>&1; then
  # usleep принимает микросекунды
  usleep $((DOUBLE_CLICK_TIMEOUT_MS * 1000))
elif python3 -c "import time; time.sleep(0.5)" 2>/dev/null; then
  # Используем Python для точного sleep
  python3 -c "import time; time.sleep(${DOUBLE_CLICK_TIMEOUT_MS}/1000.0)"
else
  # Fallback к обычному sleep (менее точный)
  sleep 1
fi

# Снова захватываем блокировку для проверки
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  echo "Не удалось захватить блокировку для проверки - возможно обрабатывается двойное нажатие"
  exit 0
fi

# Проверяем изменился ли файл (было ли второе нажатие)
if [ -f "$DOUBLE_CLICK_FILE" ]; then
  SAVED_TIME_MS=$(cat "$DOUBLE_CLICK_FILE")

  if [ "$SAVED_TIME_MS" = "$CURRENT_TIME_MS" ]; then
    echo "🔍 Обнаружено ОДИНАРНОЕ нажатие"
    rm "$DOUBLE_CLICK_FILE"  # Очищаем файл
    perform_standard_rotation
  else
    echo "Файл изменился (было: $CURRENT_TIME_MS, стало: $SAVED_TIME_MS) - обработано другим процессом"
  fi
else
  echo "Файл исчез - было двойное нажатие, обработанное другим процессом"
fi

# Освобождаем блокировку
flock -u 200

# Очистка старых файлов (на всякий случай)
find /tmp -name "power_double_click" -mmin +5 -delete 2>/dev/null || true
find /tmp -name "power_button_lock" -mmin +5 -delete 2>/dev/null || true

echo "=== Завершение скрипта ==="
