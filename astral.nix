{ inputs, ... }:
{
  imports = [
    inputs.astral-game.nixosModules.default
  ];

  programs.astral-game = {
    enable = true;
  };
}
