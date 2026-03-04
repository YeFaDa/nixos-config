{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    
    # 字体配置
    font = {
      name = "JetBrainsMono Nerd Font Mono";
      size = 12;
    };

    # 对应你文件中的 settings 部分
    settings = {
      shell = "fish";
      # 字体与风格
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";

      # 窗口装饰与透明度
      hide_window_decorations = "titlebar-only";
      window_padding_width = 15;
      background_opacity = "0.30";
      background_blur = 60;

      # 标签栏配置
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";

      # 光标轨迹 (Cursor Trail)
      cursor_trail = 600;
      cursor_trail_decay = "0.2 0.8";
      cursor_trail_color = "#769ff0";
      cursor_trail_start_threshold = -1;
      cursor_shape = "block";
      cursor_integration = "no-cursor";
    };

    # 主题配置
    # 注意：在 Home Manager 中，你可以直接指定主题名称，无需手动 include
    themeFile = "Catppuccin-Mocha";

    # 如果你需要额外的辅助配置，可以在 extraConfig 中添加原始文本
    # extraConfig = ''
    #   # 这里可以放一些 settings 没涵盖的特殊原始指令
    # '';
  };
}