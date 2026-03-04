{ pkgs, ...}:
{
    programs.vscode = {
  enable = true;
  # 这会让 Home Manager 自动帮你管理 VS Code 及其插件
  package = pkgs.vscode; 
  
  profiles.default.extensions = with pkgs.vscode-extensions; [
    ms-ceintl.vscode-language-pack-zh-hans # 中文
    jnoortheen.nix-ide                     # Nix 支持
    catppuccin.catppuccin-vsc #颜色主题
  ];

  # 你甚至可以直接在这里写 VS Code 的设置 (settings.json)
  profiles.default.userSettings = {
    "editor.fontSize" = 14;
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "nixd"; # 记得在系统里装上 nixd
    "workbench.colorTheme" = "Catppuccin Mocha";
    "terminal.integrated.defaultProfile.linux" = "fish";
  };
};

}