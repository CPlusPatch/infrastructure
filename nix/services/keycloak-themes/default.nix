{pkgs, ...}: {
  nixpkgs.overlays = [
    (final: prev: {
      custom_keycloak_themes = {
        keywind = pkgs.callPackage ./keywind.nix {};
      };
    })
  ];
}
