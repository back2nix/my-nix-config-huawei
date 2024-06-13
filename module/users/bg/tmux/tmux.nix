{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    clock24 = true;
    baseIndex = 1;
    prefix = "C-a";
    sensibleOnTop = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "screen-256color";

    extraConfig = ''
    # Feel free to NOT use this variables at all (remove, rename)
    # this are named colors, just for convenience
    color_orange="colour166" # 208, 166
    color_purple="colour134" # 135, 134
    color_green="colour076" # 070
    color_blue="colour39"
    color_yellow="colour220"
    color_red="colour160"
    color_black="colour232"
    color_white="white" # 015

    # This is a theme CONTRACT, you are required to define variables below
    # Change values, but not remove/rename variables itself
    color_dark="$color_black"
    color_light="$color_white"
    color_session_text="$color_blue"
    color_status_text="colour245"
    color_main="$color_orange"
    color_secondary="$color_purple"
    color_level_ok="$color_green"
    color_level_warn="$color_yellow"
    color_level_stress="$color_red"
    color_window_off_indicator="colour088"
    color_window_off_status_bg="colour238"
    color_window_off_status_current_bg="colour254"

    tmux_conf_copy_to_os_clipboard=true

    new-session -n $HOST
    # removing tmux delay
    set -sg escape-time 1

    # set the base index to start at 1 instead of 0
    set -g base-index 1

    # set the panes to be base 1 indexed as well
    setw -g pane-base-index 1

    # setup binding for reloading the tmux config
    # bind r source-file ~/.tmux.conf |; display "Reloaded!"

    #-------------------------------------------------------#
    #Pane copy/pasting
    #-------------------------------------------------------#
    # unbind [
    #   bind Escape copy-mode
    #   unbind p
    #   bind p paste-buffer
    #   bind -Tcopy-mode-vi v send -X begin-selection
    #   bind -Tcopy-mode-vi y send -X copy-selection
    #-------------------------------------------------------#


    # setup prefix forwarding for other applications so that tmux doesn't just capture it and
    # do nothing with it
    # bind C-a send-prefix

    #unbind C-b
    #set -g prefix C-a
    #bind C-a send-prefix

    setw -g mode-keys vi

    # change the key combinations for vertical (|) and horizontal (-) splitting to make more sense
    bind | split-window -h
    bind - split-window -v

    # setup moving between panes to use the VIM movement keys
    bind h select-pane -L
    bind j select-pane -D
    bind k select-pane -U
    bind l select-pane -R

    # quick window selection
    #bind -r C-h select-window -t :-
    #bind -r C-l select-window -t :+

    # setup pane resizing shortcuts
    bind -r H resize-pane -L 5 
    bind -r J resize-pane -D 5
    bind -r K resize-pane -U 5
    bind -r L resize-pane -R 5

    ####

    set -g terminal-overrides ",alacritty:RGB"

    set -g base-index 1
    set -g pane-base-index 1

    #### so that i can programatically change title from vim
    set-option -g set-titles on

    ##### copy to keyboard with vim binding
    bind-key v split-window -h

    ##### copy to keyboard with vim binding
    unbind-key -T copy-mode-vi Space     ;   bind-key -T copy-mode-vi v send-keys -X begin-selection
    unbind-key -T copy-mode-vi Enter     ;   bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
    unbind-key -T copy-mode-vi C-v       ;   bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
    unbind-key -T copy-mode-vi [         ;   bind-key -T copy-mode-vi [ send-keys -X begin-selection
    unbind-key -T copy-mode-vi ]         ;   bind-key -T copy-mode-vi ] send-keys -X copy-selection

    #### prefix + prefix window swapping
    bind-key a last-window
    bind '"' split-window -c "#{pane_current_path}"
    bind % split-window -h -c "#{pane_current_path}"
    bind c new-window -c "#{pane_current_path}"

    #### reload config
    bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded..."

    #### mouse mode
    set -g mouse on

    #### send prefix (so C-b works as prefix on remote)
    bind-key -n C-Tab send-prefix


    ## COLORSCHEME: gruvbox dark
    set-option -g status "on"
    set-option -g status-position top

    # default statusbar color
    set-option -g status-style bg=colour22,fg=colour82

    # default window title colors
    set-window-option -g window-status-style bg=colour22,fg=colour82

    # default window with an activity alert
    set-window-option -g window-status-activity-style bg=colour22,fg=colour82

    # active window title colors
    set-window-option -g window-status-current-style bg=colour82,fg=colour22

    # pane border
    set-option -g pane-active-border-style fg=colour82
    set-option -g pane-border-style fg=colour22

    # message infos
    set-option -g message-style bg=colour22,fg=colour82

    # writing commands inactive
    set-option -g message-command-style bg=colour22,fg=colour82

    # pane number display
    set-option -g display-panes-active-colour colour82
    set-option -g display-panes-colour colour22

    # clock
    set-window-option -g clock-mode-colour colour82

    # bell
    set-window-option -g window-status-bell-style bg=colour82,fg=colour22

    ## Theme settings mixed with colors (unfortunately, but there is no cleaner way)
    ## NOTE: there actually may be a cleaner way to set backgrounds on
    # individual plugins via their own options. see
    # https://github.com/tmux-plugins/tmux-cpu#customization
    set-option -g status-justify "left"
    set-option -g status-left-style none
    set-option -g status-left-length "80"
    set-option -g status-right-style none
    set-option -g status-right-length "80"
    set-window-option -g window-status-separator ""

    # Установка салатового цвета для различных элементов статуса
    set-option -g status-left "#[fg=colour82, bg=colour22] #S "
    set-option -ag status-right "#[fg=colour82, bg=colour22] %l:%M %p %a %d-%b-%y "
    set-window-option -g window-status-current-format "#[fg=colour22, bg=colour82] #I:#[fg=colour22, bg=colour82, bold] #W #[fg=colour82, bg=colour22, nobold, noitalics, nounderscore]"
    set-window-option -g window-status-format         "#[fg=colour82, bg=colour22] #I:#[fg=colour82, bg=colour22      ] #W #[fg=colour22, bg=colour22, noitalics]"
    # END COLORSCHEME

    unbind C-l
    unbind -T root C-l
    unbind -T copy-mode-vi C-l

    if-shell 'test -n "$SSH_CLIENT"' \
    'source-file /etc/nixos/module/users/bg/tmux/tmux.remote.conf'

    bind -T root F12  \
      set prefix None \;\
      set key-table off \;\
      set status-style "fg=$color_status_text,bg=$color_window_off_status_bg" \;\
      set window-status-current-format "#[fg=$color_window_off_status_bg,bg=$color_window_off_status_current_bg]$separator_powerline_right#[default] #I:#W# #[fg=$color_window_off_status_current_bg,bg=$color_window_off_status_bg]$separator_powerline_right#[default]" \;\
      set window-status-current-style "fg=$color_dark,bold,bg=$color_window_off_status_current_bg" \;\
      if -F '#{pane_in_mode}' 'send-keys -X cancel' \;\
      refresh-client -S \;\

    bind -T off F12 \
      set -u prefix \;\
      set -u key-table \;\
      set -u status-style \;\
      set -u window-status-current-style \;\
      set -u window-status-current-format \;\
      refresh-client -S
    '';

    plugins = with pkgs; [
      tmuxPlugins.copycat
      tmuxPlugins.resurrect
      tmuxPlugins.sensible
      tmuxPlugins.prefix-highlight
      # tmuxPlugins.tmux-update-display # not yet available on nix, but can be loaded with tpm
      tmuxPlugins.yank
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
        set -g @continuum-restore 'on'
        set -g @continuum-save-interval '60' # minutes
        '';
      }
      {
        plugin = tmuxPlugins.cpu;
        extraConfig = ''
        ### I can put these all in the color scheme section at the bottom,
        ### maybe? then use #{cpu_bg_color} instead of the color strings I'm
        ### using
        # set -g @cpu_low_fg_color "#[fg=colour246]"
        # set -g @cpu_medium_fg_color "#[fg=colour246]"
        # set -g @cpu_high_fg_color "#[fg=colour246]"
        # set -g @cpu_low_bg_color "#[bg=colour237]"
        # set -g @cpu_medium_bg_color "#[bg=colour237]"
        # set -g @cpu_high_bg_color "#[bg=colour237]"
        set -g @cpu_percentage_format " cpu: %3.1f%% "

        # set -g @ram_low_fg_color "#[fg=colour246]"
        # set -g @ram_medium_fg_color "#[fg=colour246]"
        # set -g @ram_high_fg_color "#[fg=colour246]"
        # set -g @ram_low_bg_color "#[bg=colour239]"
        # set -g @ram_medium_bg_color "#[bg=colour239]"
        # set -g @ram_high_bg_color "#[bg=colour239]"
        set -g @ram_percentage_format " mem: %3.1f%% "


        set-option -g status-right '#[fg=colour82, bg=colour22]#{cpu_percentage}'
        set-option -ag status-right '#[fg=colour82, bg=colour22]#{ram_percentage}'
        '';
      }
      {
        plugin = tmuxPlugins.battery;
        extraConfig = ''
        set-option  -ag status-right '#[fg=colour246, bg=colour239, nobold, nounderscore, noitalics] batt: #{battery_percentage} '
        '';
      }
      tmuxPlugins.vim-tmux-navigator
      tmuxPlugins.resurrect
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
        set -g @continuum-restore 'on'
        '';
      }
    ];
  };
}
