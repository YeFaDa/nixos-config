{ inputs, ... }:
{
  imports = [
    inputs.denial.nixosModules.default
  ];

  programs.denial = {
    enable = true;
  };
}
