{ config, lib, pkgs, ... }:

{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        browser = "${config.programs.firefox.package}/bin/firefox -new-tab";
        dmenu = "${pkgs.rofi}/bin/rofi -dmenu";
        follow = "mouse";
        font = "JetBrainsMono NF";
        format = "<b>%s</b>\\n%b";
        frame_color = "#1a1b26";
        frame_width = 5;
        width = "500";
        height = "300";
        offset = "30x30";
        horizontal_padding = 8;
        icon_position = "off";
        line_height = 0;
        markup = "full";
        padding = 8;
        separator_color = "frame";
        separator_height = 2;
        transparency = 10;
        word_wrap = true;
        corner_radius=8;
      };

      urgency_low = {
        background = "#1a1b26";
        foreground = "#ffffff";
        frame_color = "#fb958b";
        timeout = 10;
      };

      urgency_normal = {
        background = "#1a1b26";
        foreground = "#ffffff";
        frame_color = "#fb958b";
        timeout = 15;
      };

      urgency_critical = {
        background = "#1a1b26";
        foreground = "#ffffff";
        frame_color = "#fb958b";
        timeout = 0;
      };

      shortcuts = {
        context = "mod4+grave";
        close = "mod4+shift+space";
      };
    };
  };
}
