{ stdenv }:

stdenv.mkDerivation {
  pname = "simple-webserver";
  version = "1.0";

  src = ./.;

  buildPhase = ''
    cc -o simple-webserver server.c
  '';

  installPhase = ''
    install -Dm 755 simple-webserver $out/bin/simple-webserver
  '';
}
