#!/usr/bin/env bash
export DISPLAY=":1"
export XAUTHORITY="/run/user/1000/gdm/Xauthority"
STATE_FILE="/tmp/screen_rotation_state"

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

# Блокировка основной клавиатуры
block_keyboard() {
  MAIN_KB_ID=$(xinput list | grep "AT Translated Set 2 keyboard" | grep -o 'id=[0-9]*' | cut -d= -f2)
  if [[ -n "$MAIN_KB_ID" ]]; then
    xinput disable "$MAIN_KB_ID" 2>/dev/null
    echo "$MAIN_KB_ID" > /tmp/blocked_keyboard_id
  fi
}

# Разблокировка клавиатуры
unblock_keyboard() {
  if [ -f /tmp/blocked_keyboard_id ]; then
    KB_ID=$(cat /tmp/blocked_keyboard_id)
    xinput enable "$KB_ID" 2>/dev/null
    rm /tmp/blocked_keyboard_id
  fi
}

# Применение матрицы трансформации для устройств ввода
apply_input_transform() {
  local matrix="$1"
  xinput list --short 2>/dev/null | grep -E "slave|floating" | while IFS= read -r line; do
    device_id=$(echo "$line" | grep -o 'id=[0-9]*' | cut -d= -f2)
    if [[ -n "$device_id" ]]; then
      xinput set-prop "$device_id" "Coordinate Transformation Matrix" $matrix 2>/dev/null || true
    fi
  done
}

# Получаем текущее состояние поворота
if [ -f "$STATE_FILE" ]; then
  CURRENT_STATE=$(cat "$STATE_FILE")
else
  CURRENT_STATE="normal"
fi

# Определяем следующее состояние по часовой стрелке
case "$CURRENT_STATE" in
  "normal")
    NEXT_STATE="right"
    ROTATION="right"
    MATRIX="0 1 0 -1 0 1 0 0 1"
    MESSAGE="Экран повернут на 90° (вправо)"
    ;;
  "right")
    NEXT_STATE="inverted"
    ROTATION="inverted"
    MATRIX="-1 0 1 0 -1 1 0 0 1"
    MESSAGE="Экран повернут на 180°"
    ;;
  "inverted")
    NEXT_STATE="left"
    ROTATION="left"
    MATRIX="0 -1 1 1 0 0 0 0 1"
    MESSAGE="Экран повернут на 270° (влево)"
    ;;
  "left")
    NEXT_STATE="normal"
    ROTATION="normal"
    MATRIX="1 0 0 0 1 0 0 0 1"
    MESSAGE="Экран возвращен в нормальное положение"
    ;;
  *)
    # Если состояние неизвестно, сбрасываем в normal
    NEXT_STATE="normal"
    ROTATION="normal"
    MATRIX="1 0 0 0 1 0 0 0 1"
    MESSAGE="Экран сброшен в нормальное положение"
    ;;
esac

echo "Поворачиваем дисплей: $DISPLAY_NAME ($CURRENT_STATE -> $NEXT_STATE)"

# Применяем поворот
xrandr --output "$DISPLAY_NAME" --rotate "$ROTATION"

# Применяем трансформацию для устройств ввода
apply_input_transform "$MATRIX"

# Управляем клавиатурой: разблокируем только в нормальном положении
if [ "$NEXT_STATE" = "normal" ]; then
  unblock_keyboard
  echo "Клавиатура разблокирована"
else
  block_keyboard
  echo "Клавиатура заблокирована"
fi

# Сохраняем новое состояние
echo "$NEXT_STATE" > "$STATE_FILE"

echo "$MESSAGE"
sudo -u bg DISPLAY=":1" XAUTHORITY="/run/user/1000/gdm/Xauthority" notify-send "Поворот экрана" "$MESSAGE" 2>/dev/null || true
