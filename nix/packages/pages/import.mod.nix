{...}: {
  nixpkgs.overlays = [
    (final: prev: {
      cpluspatch-pages = final.callPackage ./package.nix {};
    })
  ];
}
