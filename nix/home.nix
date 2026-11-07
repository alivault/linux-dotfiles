# Ali's personal files (home-manager).
#
# - Every file in home/ is linked into the home at the same path, through
#   the checkout (mkOutOfStoreSymlink): ~/.bashrc -> /nix/store/...-hm_.bashrc
#   -> <checkout>/home/.bashrc. An edit in the home is an edit in git at once;
#   a new file needs `git add` and a switch. The list of files comes from this
#   flake's copy of home/, the content from the checkout.
# - Files that apps write (seed/) are not linked: bin/dotfiles-seed copies
#   them where they are missing.
# - The Oasis session units are not here: Oasis's own module links them.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles;
  homeDir = config.home.homeDirectory;
  link = rel: config.lib.file.mkOutOfStoreSymlink "${cfg.checkout}/home/${rel}";

  tree = ../home;
  files = lib.subtractLists cfg.exclude (
    map (path: lib.removePrefix "${toString tree}/" (toString path)) (
      lib.filesystem.listFilesRecursive tree
    )
  );

  # The MCP servers pi starts. It has the home's path in it, so Nix writes it.
  mcp = (pkgs.formats.json { }).generate "pi-mcp.json" {
    mcpServers = {
      oasis = {
        command = "${homeDir}/.local/share/oasis/current/bin/oasis-mcp";
        description = "The Oasis desktop as data (read-only): windows, focus, workspaces, outputs, notifications, settings with their schema, oasis commands, Quickshell IPC targets, and desktop events (get_events waits for the next).";
      };
      chrome = {
        command = "npx";
        args = [
          "-y"
          "chrome-devtools-mcp@latest"
          "--autoConnect"
          "--userDataDir=${homeDir}/.config/chromium"
          "--no-usage-statistics"
        ];
        description = "Ali's real Chromium session (logins, cookies, tabs) over Chrome DevTools. Needs remote debugging on in chrome://inspect/#remote-debugging.";
      };
    };
  };
in
{
  options.dotfiles = {
    enable = lib.mkEnableOption "Ali's personal files, linked from the dotfiles checkout";

    checkout = lib.mkOption {
      type = lib.types.str;
      default = "${homeDir}/code/dotfiles";
      defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/code/dotfiles"'';
      description = ''
        The git checkout of this repository. The links point into it, so it
        must be there before the switch (the activation stops if it is not).
      '';
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ ".config/kitty/kitty.conf" ];
      description = "Paths in home/ (relative to it) that this Mac does not link.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file =
      lib.genAttrs files (rel: {
        source = link rel;
      })
      // {
        # One set of agent rules for every agent.
        ".claude/CLAUDE.md".source = link ".pi/agent/AGENTS.md";
        ".codex/AGENTS.md".source = link ".pi/agent/AGENTS.md";
        ".pi/agent/mcp.json".source = mcp;
      };

    # Without the checkout every link would point at nothing (no ~/.bashrc,
    # no rm guard for agents). Stop before home-manager moves or links a file.
    home.activation.dotfilesCheckout = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ ! -d ${lib.escapeShellArg "${cfg.checkout}/home"} ]; then
        echo "dotfiles: no checkout at ${cfg.checkout}" >&2
        echo "dotfiles: clone it first: git clone https://github.com/alivault/linux-dotfiles ${cfg.checkout}" >&2
        exit 1
      fi
    '';
  };
}
