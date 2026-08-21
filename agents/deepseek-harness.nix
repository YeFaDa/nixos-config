{ inputs, pkgs, ... }:
{
  imports = [ inputs.deepseek-harness.nixosModules.default ];

  programs.dsh.enable = true;
}
