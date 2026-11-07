{
  pkgs,
  pkgs-master,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    alejandra
    nix-init # <- generate nix package expressions from url
    nix-inspect # <- configuration inspector
    nix-melt # <- flake.lock explorer
    nixfmt
    nixpkgs-review
    nvd # <- diff package changes between versions
    nix-output-monitor # <- nom: дерево сборки вживую (nh использует его)
    nix-tree # <- интерактивно: что раздувает closure (`nix-tree /run/current-system`)
    nix-du # <- граф занятого места в store (`nix-du -s=500MB | dot -Tsvg > du.svg`)
    nix-diff # <- почему пересобирается: `nix-diff old.drv new.drv`
  ];

  # nh: красивый rebuild (nom + nvd-дифф). Чистку не включаем — её делает nix.gc.
  programs.nh = {
    enable = true;
    flake = "/home/bg/Documents/code/github.com/back2nix/nix/my-nix-config-huawei";
  };

  # Atuin: история в SQLite (папка, код выхода, длительность). Ctrl-R — atuin,
  # стрелка вверх остаётся родной fish. Синк между машинами: `atuin register`/`login`.
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = ["--disable-up-arrow"];
    settings = {
      style = "compact";
      inline_height = 20;
      filter_mode_shell_up_key_binding = "session";
      enter_accept = false;
      auto_sync = true;
      sync_frequency = "10m";
      update_check = false;
    };
  };

  # fzf тоже вешается на Ctrl-R — atuin должен победить.
  programs.fish.interactiveShellInit = lib.mkAfter ''
    bind \cr _atuin_search
    bind -M insert \cr _atuin_search
  '';
}
