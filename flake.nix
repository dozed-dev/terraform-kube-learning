{
  description = "Devshell for terraform";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [ opentofu jq talosctl ];
      shellHook = ''
        source ./setup_access.sh
      '';
    };
  };
}
