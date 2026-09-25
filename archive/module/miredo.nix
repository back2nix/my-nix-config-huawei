{
  config,
  pkgs,
  ...
}: {
  services.miredo = {
    enable = true;
    package = pkgs.miredo;
    # serverAddress = "teredo.remlab.net"; # Или другой сервер Teredo
    # serverAddress = "teredo.ipv6.microsoft.com"; # Или другой сервер Teredo
    serverAddress = "217.17.192.217"; # Или другой сервер Teredo
    bindAddress = "0.0.0.0"; # Привязка ко всем интерфейсам
    bindPort = "3545"; # Стандартный порт Teredo
    interfaceName = "teredo"; # Имя создаваемого интерфейса
  };
}
