{ config, pkgs, ... }:
with pkgs;
with builtins;
let
  scriptContent = # bash
    ''
      ALACRITTY_CONFIG=~/.config/alacritty
      ALACRITTY_THEME=~/.alacritty_theme.toml
      SYSTEM_THEME=$([ "$DARKMODE" = "1" ] && echo "dark" || echo "light")
      /bin/ln -sf "$ALACRITTY_CONFIG/themes/$SYSTEM_THEME.toml" "$ALACRITTY_THEME"
    '';
  scriptPath = (toString (writeShellScript "home-alacritty-theme.sh" scriptContent));
  cmdPath = (toString (lib.getExe dark-mode-notify));
in
{
  launchd.agents = {
    "alacritty-theme-helper" = {
      enable = true;
      config = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/bin/wait4path ${cmdPath} &amp;&amp; ${cmdPath} ${scriptPath}"
        ];
        KeepAlive = true;
        RunAtLoad = true;
      };
    };
  };
}
