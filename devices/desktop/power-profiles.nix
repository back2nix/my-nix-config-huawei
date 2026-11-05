# devices/desktop/power-profiles.nix
#
# Ryzen 9 3900XT: amd_pstate не стартует (BIOS не отдаёт CPPC), поэтому
# power-profiles-daemon работает с placeholder-драйвером и предлагает только
# balanced/power-saver, которые ничего не делают.
#
# Решение: включаем "fake"-драйвер ppd (он принимает все 3 профиля, в т.ч.
# performance — появляется в быстрых настройках GNOME), а отдельный сервис
# слушает ActiveProfile по D-Bus и сам переключает governor/boost.
{
  pkgs,
  lib,
  ...
}: let
  apply = pkgs.writeShellScript "ppd-cpufreq-apply" ''
    set -u
    profile="$1"
    case "$profile" in
      performance) gov=performance; boost=1 ;;
      power-saver) gov=schedutil;   boost=0 ;;
      *)           gov=schedutil;   boost=1 ;;
    esac
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
      echo "$gov" > "$f"
    done
    [ -w /sys/devices/system/cpu/cpufreq/boost ] && echo "$boost" > /sys/devices/system/cpu/cpufreq/boost
    echo "profile=$profile governor=$gov boost=$boost"
  '';

  watcher = pkgs.writeShellScript "ppd-cpufreq-watch" ''
    set -u
    export PATH=${lib.makeBinPath [pkgs.glib pkgs.gnugrep pkgs.gnused pkgs.coreutils]}
    current() {
      gdbus call --system --dest net.hadess.PowerProfiles \
        --object-path /net/hadess/PowerProfiles \
        --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile \
        | grep -oE "performance|balanced|power-saver"
    }
    last="$(current)"
    ${apply} "$last"
    gdbus monitor --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles \
      | grep --line-buffered "ActiveProfile" \
      | while read -r _; do
          p="$(current)"
          if [ -n "$p" ] && [ "$p" != "$last" ]; then
            ${apply} "$p"
            last="$p"
          fi
        done
  '';
in {
  services.power-profiles-daemon.enable = true;
  systemd.services.power-profiles-daemon.environment.POWER_PROFILE_DAEMON_FAKE_DRIVER = "1";

  systemd.services.ppd-cpufreq = {
    description = "Apply power-profiles-daemon profile to CPU governor";
    after = ["power-profiles-daemon.service"];
    requires = ["power-profiles-daemon.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = watcher;
      Restart = "always";
      RestartSec = 2;
    };
  };
}
