{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    aggressiveResize = false;
    historyLimit = 100000;
    resizeAmount = 5;
    escapeTime = 0;
    secureSocket = false;
    clock24 = true;
    baseIndex = 1;
    prefix = "C-a";
    sensibleOnTop = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "screen-256color";

    plugins = with pkgs; [
      tmuxPlugins.copycat
      tmuxPlugins.sensible
      tmuxPlugins.yank
      tmuxPlugins.vim-tmux-navigator
      # tmuxPlugins.fingers
      # tmuxPlugins.net-speed
      # tmuxPlugins.cpu
      # tmuxPlugins.battery
      # {
      #   plugin = tmuxPlugins.battery;
      #   # extraConfig = ''
      #   #   set-option -g status-right '#[fg=#5c6370, bg=#282c34, nobold, nounderscore, noitalics] batt: #{battery_percentage} '
      #   # '';
      # }
      # tmuxPlugins.nord
      tmuxPlugins.onedark-theme
    ];

    extraConfig = ''
      set -g mouse on
      unbind -n MouseDrag1Pane
      bind -n MouseDrag1Pane if -F '#{mouse_any_flag}' 'if -F "#{pane_in_mode}" "copy-mode -M" "send-keys -M"' 'copy-mode -M'

      # Pane and window management
      bind '"' split-window -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Other bindings
      bind a last-window

      # Unbind Ctrl+L to prevent window switching
      unbind C-l
      unbind -T root C-l
      unbind -T copy-mode-vi C-l

      # Remote session handling
      if-shell 'test -n "$SSH_CLIENT"' \
        'source-file /etc/nixos/module/users/bg/tmux/tmux.remote.conf'

      # Toggle key table (modified to work with onedark theme)
      bind -T root M-m \
        set prefix None \;\
        set key-table off \;\
        set status-style "fg=#5c6370,bg=#282c34" \;\
        set window-status-current-format "#[fg=#282c34,bg=#5c6370]#[default] #I:#W# #[fg=#5c6370,bg=#282c34]#[default]" \;\
        set window-status-current-style "fg=#282c34,bold,bg=#5c6370" \;\
        if -F '#{pane_in_mode}' 'send-keys -X cancel' \;\
        refresh-client -S

      bind -T off M-m \
        set -u prefix \;\
        set -u key-table \;\
        set -u status-style \;\
        set -u window-status-current-style \;\
        set -u window-status-current-format \;\
        refresh-client -S
    '';
  };
}
