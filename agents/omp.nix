{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.omp-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
