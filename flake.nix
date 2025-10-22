{
  description = "Devshell for terraform";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    simple-webserver = pkgs.callPackage ./simple-webserver { stdenv = pkgs.pkgsMusl.stdenv; };
  in {
    packages.${system}.webserver-image = pkgs.dockerTools.buildImage {
      name = "simple-webserver";
      tag = "latest";
      config = {
        Entrypoint = ["${simple-webserver}/bin/simple-webserver"];
        ExposedPorts = {
          "8080/tcp" = {};
        };
      };
    };
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [ opentofu jq talosctl simple-webserver ];
      shellHook = ''
        ln -sf ${self.packages.${system}.webserver-image} out/docker-image-simple-webserver.tar.gz
        source ./setup_access.sh
      '';
    };
  };
}
