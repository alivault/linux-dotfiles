# Ali's personal files, as a home-manager module.
#
# The Oasis flake (github:alivault/oasis) takes this flake as an input and
# imports homeManagerModules.default for the user ali on both Macs. The module
# links each file in home/ to the same file in the checkout of this repository
# (option dotfiles.checkout), so an edit in the home is an edit in git.
# README.md, "Moving off chezmoi", tells how it works.
{
  description = "Ali's dotfiles: a home-manager module that links home/ from the checkout";

  outputs =
    { self }:
    {
      homeManagerModules.default = import ./nix/home.nix;
      homeManagerModules.dotfiles = self.homeManagerModules.default;
    };
}
