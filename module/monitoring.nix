{ config, lib, pkgs, ... }:

with lib;

{
  options = {
    services.monitoring-stack = {
      enable = mkEnableOption "Enable full monitoring stack (Prometheus + Grafana + Node Exporter)";

      prometheus.port = mkOption {
        type = types.port;
        default = 9090;
        description = "Port for Prometheus";
      };

      grafana.port = mkOption {
        type = types.port;
        default = 3000;
        description = "Port for Grafana";
      };

      node-exporter.port = mkOption {
        type = types.port;
        default = 9100;
        description = "Port for Node Exporter";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Open firewall for all monitoring ports";
      };
    };
  };

  config = mkIf config.services.monitoring-stack.enable {
    # Node Exporter
    services.prometheus.exporters.node = {
      enable = true;
      port = config.services.monitoring-stack.node-exporter.port;
      enabledCollectors = [
        "systemd"
        "filesystem"
        "loadavg"
        "meminfo"
        "netdev"
        "stat"
        "time"
        "vmstat"
      ];
    };

    # Prometheus с метриками Blocky
    services.prometheus = {
      enable = true;
      port = config.services.monitoring-stack.prometheus.port;

      scrapeConfigs = [
        {
          job_name = "node-exporter";
          static_configs = [{
            targets = [ "localhost:${toString config.services.monitoring-stack.node-exporter.port}" ];
          }];
        }
        {
          job_name = "prometheus";
          static_configs = [{
            targets = [ "localhost:${toString config.services.monitoring-stack.prometheus.port}" ];
          }];
        }
        # ДОБАВЛЯЕМ BLOCKY МЕТРИКИ
        {
          job_name = "blocky";
          scrape_interval = "15s";
          static_configs = [{
            targets = [ "localhost:4000" ];
          }];
        }
      ];
    };

    # Grafana с PostgreSQL источником данных
    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = config.services.monitoring-stack.grafana.port;
        };
        security = {
          admin_user = "admin";
          admin_password = "admin";
        };
        # Разрешаем небезопасный HTML для piechart панелей
        panels.disable_sanitize_html = true;
      };

      # Устанавливаем плагин piechart
      declarativePlugins = with pkgs.grafanaPlugins; [
        grafana-piechart-panel
      ];

      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://localhost:${toString config.services.monitoring-stack.prometheus.port}";
              isDefault = true;
            }
            # ДОБАВЛЯЕМ POSTGRESQL ИСТОЧНИК ДЛЯ BLOCKY ЛОГОВ
            {
              name = "Blocky Query Log";
              type = "postgres";
              url = "localhost:5432";
              database = "blocky";
              user = "grafana";
              jsonData = {
                sslmode = "disable";
                database = "blocky";
              };
              orgId = 1;
            }
          ];
        };
      };
    };

    # Открываем порты
    networking.firewall = mkIf config.services.monitoring-stack.openFirewall {
      allowedTCPPorts = [
        config.services.monitoring-stack.prometheus.port
        config.services.monitoring-stack.grafana.port
        config.services.monitoring-stack.node-exporter.port
      ];
    };
  };
}
