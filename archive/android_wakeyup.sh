#!/usr/bin/env bash

# Отключаем оптимизацию батареи и запрещаем уходить в сон
adb shell dumpsys deviceidle disable
# Разрешаем системе работать при выключенном экране
adb shell svc power stayon true

echo "Цикл поддержания сетевой активности запущен. Экран можно выключить вручную."

while true; do
  adb shell input keyevent 0 || true
  # Включаем и сразу выключаем экран, чтобы сбросить таймеры
  adb shell "input keyevent 224 && input keyevent 223" || true

  # Печатаем точку без перехода на новую строку
  echo -n "."

  sleep 120
done
