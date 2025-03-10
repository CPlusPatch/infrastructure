{config}: let
  nixosVars = builtins.fromJSON (builtins.readFile ../../terraform/nixos-vars.json);
  currentVars = nixosVars.${config.networking.hostName};
in {currentVars = currentVars;}
