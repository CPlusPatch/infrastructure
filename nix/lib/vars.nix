{config}: let
  currentDir = builtins.substring 0 (builtins.length ./. - 1) ./.;
  nixosVars = builtins.fromJSON (builtins.readFile ../../terraform/nixos-vars.json);
  currentVars = nixosVars.${currentDir};
in {currentVars = currentVars;}
