# This function creates a NixOS system based on our VM setup for a
# particular architecture.
{ nixpkgs, inputs }:

name:
{
  system,
  user,
  darwin ? false,
  wsl ? false,
}:
let
  # True if this is a WSL system.
  isWSL = wsl;

  # Machine configuration for all users.
  machineConfig = ../machines/${name}.nix;

  # System configuration for a specific user.
  userSystemGenericConfig = ../users/${user}/${if darwin then "darwin" else "nixos"}.nix;
  userSystemSpecificConfig = ../users/${user}/${if darwin then "darwin-${name}.nix" else "nixos-${name}.nix"};
  userSystemConfig =
    if builtins.pathExists userSystemSpecificConfig then userSystemSpecificConfig else userSystemGenericConfig;

  # User specific configuration (shared across all machines)
  userHomeConfig = ../users/${user}/home.nix;

  # NixOS vs nix-darwin functions
  systemFunc = if darwin then inputs.nix-darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
  home-manager = if darwin then inputs.home-manager.darwinModules else inputs.home-manager.nixosModules;
in
systemFunc {
  inherit system inputs;
  modules = [
    # Allow unfree packages.
    { nixpkgs.config.allowUnfree = true; }
    # Bring in WSL if this is a WSL build
    (if isWSL then inputs.nixos-wsl.nixosModules.wsl else { })
    # Fixes .app programs installed by Nix on macOS
    (if darwin then inputs.mac-app-util.darwinModules.default else { })
    machineConfig
    userSystemConfig
    home-manager.home-manager
    {
      home-manager.backupFileExtension = ".hm-backup";
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.sharedModules = [
        (if darwin then inputs.mac-app-util.homeManagerModules.default else { })
      ];
      home-manager.users.${user} = import userHomeConfig {
        isWSL = isWSL;
        inputs = inputs;
      };
    }
    # # (
    # #   if darwin then
    #     # Fully manage Homebrew on macOS with Nix
    #     inputs.nix-homebrew.darwinModules.nix-homebrew {
    #       nix-homebrew = {
    #         enable = true;
    #         enableRosetta = true;
    #         # User owning the Homebrew prefix
    #         user = "nick";
    #         # Optional: Declarative tap management
    #         taps = {
    #           "homebrew/homebrew-core" = inputs.homebrew-core;
    #           "homebrew/homebrew-cask" = inputs.homebrew-cask;
    #           "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
    #         };
    #         # With mutableTaps disabled, taps can no longer be added imperatively with `brew tap`.
    #         mutableTaps = false;
    #       };
    #     }
    # #   else
    # #     { }
    # # )

    # We expose some extra arguments so that our modules can parameterize
    # better based on these values.
    {
      config._module.args = {
        currentSystem = system;
        currentSystemName = name;
        currentSystemUser = user;
        isWSL = isWSL;
        inputs = inputs;
      };
    }
  ];
}