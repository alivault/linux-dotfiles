# Linux adaptation of ~/code/dotfiles-reference/fish.
fish_add_path --path "$HOME/.local/bin" "$HOME/.local/share/mise/shims"
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx TERMINAL kitty
if not set -q FFF_ENABLE_HOME_SCAN
    set -gx FFF_ENABLE_HOME_SCAN 0
end

if test -r "$HOME/.cargo/env.fish"
    source "$HOME/.cargo/env.fish"
end

if status is-interactive
    set -g fish_greeting
    fish_vi_key_bindings
    bind -M default yy fish_clipboard_copy
    bind -M default Y fish_clipboard_copy
    bind -M default p fish_clipboard_paste

    set -g fish_color_command blue
    set -g fish_color_param cyan
    set -g fish_color_quote yellow
    set -g fish_color_comment red
    set -g fish_color_autosuggestion brblack

    if command -q mise
        mise activate fish | source
    end
    if command -q zoxide
        zoxide init fish | source
    end
    if command -q fzf
        set -gx FZF_DEFAULT_OPTS '--height=100% --bind "ctrl-/:toggle-preview" --bind "shift-up:preview-page-up,shift-down:preview-page-down"'
        if command -q eza; and command -q bat
            set -gx FZF_CTRL_T_OPTS '--preview "if test -d {}; eza --tree --level=3 --color=always --icons=always --group-directories-first -- {} | head -250; else bat --style=numbers --color=always --line-range :500 -- {}; end" --preview-window=right,80%,border-left'
            set -gx FZF_ALT_C_OPTS '--preview "eza --tree --level=3 --color=always --icons=always --group-directories-first -- {} | head -250" --preview-window=right,80%,border-left'
        end
        fzf --fish | source
        bind -M insert ctrl-o fzf-cd-widget
        bind -M insert ctrl-f fzf-file-widget
    end
    if command -q starship
        starship init fish | source
    end

    abbr -a c clear
    abbr -a x exit
    abbr -a v nvim
    abbr -a pd 'pnpm dev'
    abbr -a glog 'git log --oneline --graph --color --all --decorate'
    abbr -a yt yt-dlp
    abbr -a lg lazygit
    abbr -a j zellij
    abbr -a ts 'tmux new-session -A -s'
    abbr -a tls 'tmux ls'
    abbr -a tk 'tmux kill-session -t'
    alias ll 'ls -alh'
    alias vim nvim

    # Use the Linux desktop trash, never the macOS ~/.Trash directory.
    if command -q gio
        alias trash 'gio trash'
    end
end

function wipe --description 'Clear screen and scrollback'
    printf '\033[2J\033[3J\033[1;1H'
end
