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
    # shell = "${pkgs.zsh}/bin/zsh";
    shell = "${pkgs.fish}/bin/fish";
    terminal = "screen-256color";
    plugins = with pkgs; [
      # tmuxPlugins.copycat
      tmuxPlugins.sensible
      tmuxPlugins.yank
      tmuxPlugins.vim-tmux-navigator
      # tmuxPlugins.onedark-theme  # сломан: шебанг /bin/bash отсутствует на NixOS
      #                              + опции tmux 2.x удалены в 3.x. Тема встроена ниже.
    ];
    extraConfig = ''
        # --- Тема onedark (встроена вместо плагина onedark-theme) ---
        # Современный синтаксис tmux 3.x (-style вместо *-fg/*-bg/*-attr)
        set -g status on
        set -g status-justify left
        set -g status-left-length 100
        set -g status-right-length 100

        set -g status-style "fg=#aab2bf,bg=#282c34"
        set -g message-style "fg=#aab2bf,bg=#282c34"
        set -g message-command-style "fg=#aab2bf,bg=#282c34"

        setw -g window-status-style "fg=#282c34,bg=#282c34"
        setw -g window-status-activity-style "fg=#282c34,bg=#282c34"
        setw -g window-status-separator ""

        set -g window-style "fg=#5c6370"
        set -g window-active-style "fg=#aab2bf"

        set -g pane-border-style "fg=#aab2bf,bg=#282c34"
        set -g pane-active-border-style "fg=#98c379,bg=#282c34"

        set -g display-panes-active-colour "#e5c07b"
        set -g display-panes-colour "#61afef"

        set -g status-right "#[fg=#aab2bf,bg=#282c34,nounderscore,noitalics]%R  %d/%m/%Y #[fg=#3e4452,bg=#282c34]#[fg=#3e4452,bg=#3e4452]#[fg=#aab2bf,bg=#3e4452] #[fg=#98c379,bg=#3e4452,nobold,nounderscore,noitalics]#[fg=#282c34,bg=#98c379,bold] #h #[fg=#e5c07b,bg=#98c379]#[fg=#e06c75,bg=#e5c07b]"
        set -g status-left "#[fg=#282c34,bg=#98c379,bold] #S #[fg=#98c379,bg=#282c34,nobold,nounderscore,noitalics]"
        set -g window-status-format "#[fg=#282c34,bg=#282c34,nobold,nounderscore,noitalics]#[fg=#aab2bf,bg=#282c34] #I  #W #[fg=#282c34,bg=#282c34,nobold,nounderscore,noitalics]"
        set -g window-status-current-format "#[fg=#282c34,bg=#3e4452,nobold,nounderscore,noitalics]#[fg=#aab2bf,bg=#3e4452,nobold] #I  #W #[fg=#3e4452,bg=#282c34,nobold,nounderscore,noitalics]"
        # --- конец темы onedark ---

        # OSC 52 clipboard passthrough: works through SSH without X11 tricks
        # screen-256color doesn't advertise Ms by default, so we add it manually
        set -g set-clipboard on
        set -ga terminal-overrides ',screen-256color:Ms=\E]52;%p1%s;%p2%s\007'

        set -g mouse on
        unbind -n MouseDrag1Pane
        bind -n MouseDrag1Pane if -F '#{mouse_any_flag}' 'if -F "#{pane_in_mode}" "copy-mode -M" "send-keys -M"' 'copy-mode -M'

        # Split windows (работает с обеими раскладками по умолчанию)
        bind '"' split-window -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"
        bind c new-window -c "#{pane_current_path}"

        # Vim-style копирование (работает независимо от раскладки в режиме vi)
        bind -T copy-mode-vi v send-keys -X begin-selection
        # y: copy-selection-and-cancel + set-clipboard on → tmux отправляет OSC 52 → kitty
        bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
        bind -T copy-mode-vi r send-keys -X rectangle-toggle

        # Last window (работает с обеими раскладками)
        bind a last-window
        bind ф last-window

        # Unbind navigation keys
        unbind C-l
        unbind -T root C-l
        unbind -T copy-mode-vi C-l

        # SSH check
        if-shell 'test -n "$SSH_CLIENT"' \
          'source-file /etc/nixos/module/users/bg/tmux/tmux.remote.conf'

        # Toggle prefix key and status bar (латинские буквы)
        bind -T root M-m \
          set prefix None \;\
          set key-table off \;\
          set status-style "fg=#5c6370,bg=#282c34" \;\
          set window-status-current-format "#[fg=#282c34,bg=#5c6370]#[default] #I:#W# #[fg=#5c6370,bg=#282c34]#[default]" \;\
          set window-status-current-style "fg=#282c34,bold,bg=#5c6370" \;\
          if -F '#{pane_in_mode}' 'send-keys -X cancel' \;\
          refresh-client -S

        # Toggle prefix key and status bar (русские буквы)
        bind -T root 'M-ь' \
          set prefix None \;\
          set key-table off \;\
          set status-style "fg=#5c6370,bg=#282c34" \;\
          set window-status-current-format "#[fg=#282c34,bg=#5c6370]#[default] #I:#W# #[fg=#5c6370,bg=#282c34]#[default]" \;\
          set window-status-current-style "fg=#282c34,bold,bg=#5c6370" \;\
          if -F '#{pane_in_mode}' 'send-keys -X cancel' \;\
          refresh-client -S

        # Restore prefix key and status bar (латинские буквы)
        bind -T off M-m \
          set -u prefix \;\
          set -u key-table \;\
          set -u status-style \;\
          set -u window-status-current-style \;\
          set -u window-status-current-format \;\
          refresh-client -S

        # Restore prefix key and status bar (русские буквы)
        bind -T off 'M-ь' \
          set -u prefix \;\
          set -u key-table \;\
          set -u status-style \;\
          set -u window-status-current-style \;\
          set -u window-status-current-format \;\
          refresh-client -S

        # Unbind keys that we're redefining
        unbind -n S-Space
        unbind M-m
        unbind 'M-ь'

        # Навигация между панелями (латинские буквы)
        bind -n M-h select-pane -L
        bind -n M-j select-pane -D
        bind -n M-k select-pane -U
        bind -n M-l select-pane -R

        # Навигация между панелями (русские буквы)
        bind -n M-р select-pane -L
        bind -n M-о select-pane -D
        bind -n M-л select-pane -U
        bind -n M-д select-pane -R

        # Изменение размера панелей (латинские буквы)
        bind -n M-H resize-pane -L 5
        bind -n M-J resize-pane -D 5
        bind -n M-K resize-pane -U 5
        bind -n M-L resize-pane -R 5

        # Изменение размера панелей (русские буквы)
        bind -n M-Р resize-pane -L 5
        bind -n M-О resize-pane -D 5
        bind -n M-Л resize-pane -U 5
        bind -n M-Д resize-pane -R 5

      # Отключаем tmux-copycat Ctrl+R и используем Fish fzf
        unbind -n C-r
        bind -n C-r send-keys C-r

        # Отключить C-a + Space (next-layout, менял расположение панелей)
        unbind Space
    '';
  };
}
