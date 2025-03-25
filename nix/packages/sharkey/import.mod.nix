{...}: {
  imports = [
    (import ./module.nix)
  ];

  nixpkgs.overlays = [
    (final: prev: {
      sharkey = final.callPackage ./package.nix {};
    })
  ];
}
