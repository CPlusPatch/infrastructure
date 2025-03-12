final: prev: {
  matrix-synapse = prev.matrix-synapse.overrideAttrs (old: rec {
    pname = "matrix-synapse";
    version = "1.126.0";

    src = prev.fetchFromGitHub {
      owner = "element-hq";
      repo = "synapse";
      rev = "v${version}";
      hash = "sha256-fEJ4gxftC9oPhmcvbMdwxbZsHVfed9NS8Sjb7BTmTQo=";
    };

    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      inherit src;
      name = "${pname}-${version}";
      hash = "sha256-P0JNGaRUd3fiwfPLnXQGeTDTURLgqO6g4KRIs86omYg=";
    };
  });
}
