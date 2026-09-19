{ inputs, ... }:
{
  imports = [ inputs.flclash-nix.nixosModules.flclash ];

  programs.flclash = { enable = true; tunMode = true; owner = "yz"; };
}
