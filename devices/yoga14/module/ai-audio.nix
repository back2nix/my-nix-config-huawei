{ pkgs, ... }: {
  # Пользовательский сервис, который настраивает маршрутизацию звука (Mix-Minus).
  # Создает "Ловушку" (AI_System_Proxy), перенаправляет в нее весь системный звук,
  # а затем пересылает его в реальные наушники через Loopback.
  systemd.user.services.ai-audio-bridge = {
    description = "AI Audio Mix-Minus Bridge";
    after = [ "pipewire-pulse.service" "wireplumber.service" ];
    wants = [ "pipewire-pulse.service" ];
    wantedBy = [ "default.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      # Скрипт инициализации с полными путями
      ExecStart = pkgs.writeShellScript "init-ai-audio" ''
        # Определяем пути к утилитам
        PACTL=${pkgs.pulseaudio}/bin/pactl
        GREP=${pkgs.gnugrep}/bin/grep
        AWK=${pkgs.gawk}/bin/awk
        SLEEP=${pkgs.coreutils}/bin/sleep

        # Ждем стабилизации PipeWire
        $SLEEP 5

        # 1. Запоминаем текущий реальный выход (наушники/динамики)
        # Если "AI_System_Proxy" уже стоит по умолчанию (после рестарта), пытаемся найти что-то другое
        CURRENT_SINK=$($PACTL get-default-sink)

        if [[ "$CURRENT_SINK" == "AI_System_Proxy" ]]; then
           # Пытаемся найти первый попавшийся Sink, который НЕ Proxy
           CURRENT_SINK=$($PACTL list short sinks | $GREP -v "AI_System_Proxy" | $AWK '{print $2}' | head -n 1)
        fi

        if [[ -z "$CURRENT_SINK" ]]; then
           echo "No physical sink found, skipping loopback setup"
           exit 0
        fi

        echo "Physical Sink detected: $CURRENT_SINK"

        # 2. Создаем виртуальный Sink (Ловушку), если его нет
        if ! $PACTL list short sinks | $GREP -q "AI_System_Proxy"; then
            echo "Creating AI_System_Proxy sink..."
            $PACTL load-module module-null-sink \
                sink_name=AI_System_Proxy \
                sink_properties=device.description="AI_System_Proxy"
        fi

        # 3. Создаем Loopback: AI_System_Proxy -> Real Sink
        # Это нужно, чтобы ты слышал то, что играет в "Ловушке"
        if ! $PACTL list short modules | $GREP -q "source=AI_System_Proxy.monitor"; then
            echo "Creating Loopback to $CURRENT_SINK..."
            $PACTL load-module module-loopback \
                source=AI_System_Proxy.monitor \
                sink=$CURRENT_SINK \
                latency_msec=50 \
                sink_input_properties=media.role=music
        fi

        # 4. Делаем Ловушку устройством по умолчанию для всей системы
        echo "Setting AI_System_Proxy as default sink..."
        $PACTL set-default-sink AI_System_Proxy
      '';

      ExecStop = pkgs.writeShellScript "stop-ai-audio" ''
        PACTL=${pkgs.pulseaudio}/bin/pactl

        $PACTL unload-module module-null-sink 2>/dev/null || true
        $PACTL unload-module module-loopback 2>/dev/null || true
      '';
    };
  };
}
