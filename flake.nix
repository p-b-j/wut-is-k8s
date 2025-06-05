{
  description = "exploring k8s";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    ,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ ];
        };
      in
      {
        devShells = {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              kind
              kubectl
            ];

          };
        };
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
