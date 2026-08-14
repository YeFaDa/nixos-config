{ config, lib, pkgs, inputs, ... }:
let
  # flake input 的拓展集：extensions.<系统>.open-vsx.<发布者>.<扩展名>
  extensions = inputs.vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.open-vsx;
in
{
  # VSCode（MS 二进制版）+ 声明式拓展（nix-community/nix-vscode-extensions，Open VSX 源）
  environment.systemPackages = with pkgs; [
    (vscode-with-extensions.override {
      vscodeExtensions = with extensions; [
        # ---- Nix 语法 / 解释器支持（LSP 用系统里的 nixd/nil）----
        jnoortheen.nix-ide
        arrterian.nix-env-selector

        # ---- GitHub 官方拓展 ----
        github.vscode-codeql
        github.vscode-github-actions
        github.vscode-pull-request-github

        # GitHub 生态（GitKraken 出品，GitHub 集成最强的工具）
        eamodio.gitlens

        # Noctalia 主题
        noctalia.noctaliatheme

        # 简体中文界面语言包（ms-ceintl 发布，marketplace 源）
        ms-ceintl.vscode-language-pack-zh-hans

        # 注意：Copilot 本体（github.copilot）和 Pylance 等微软私有拓展不在 Open VSX，装不了
      ];
    })
  ];
}
