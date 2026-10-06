{
  description = "Default flake-parts based setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [inputs.treefmt-nix.flakeModule];
      systems = import inputs.systems;
      perSystem = {
        self',
        lib,
        pkgs,
        ...
      }: let
        fs = lib.fileset;
        arcsigns-plugin = pkgs.vimUtils.buildVimPlugin {
          name = "arcsigns";
          src = fs.toSource {
            root = ./.;
            fileset = fs.unions [
              ./plugin
              ./lua
            ];
          };
        };
      in {
        packages = {
          default = arcsigns-plugin;
          nvim-dev = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
            withPython3 = false;
            withNodeJs = false;
            plugins = [self'.packages.default];
            customRC = ''
              lua <<EOF
              require("arcsigns").setup({})
              EOF
            '';
          };
        };
        devShells.default = pkgs.mkShellNoCC {
          buildInputs = [self'.packages.nvim-dev];
        };
        treefmt = import ./treefmt.nix;
      };
    };
}
