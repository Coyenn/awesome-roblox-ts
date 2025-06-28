{
  description = "Development environment with Lune";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rbx-pkgs-flake.url = "github:Coyenn/pkgs";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rbx-pkgs-flake,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
        rbx-pkgs = rbx-pkgs-flake.packages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            rbx-pkgs.lune
          ];
        };
      }
    );
}
