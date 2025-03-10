{stdenv}:
stdenv.mkDerivation {
  name = "Keywind Keycloak Theme";
  version = "1.0";

  src = ./theme/keywind;

  nativeBuildInputs = [];
  buildInputs = [];

  installPhase = ''
    mkdir -p $out
    cp -a login $out
  '';
}
