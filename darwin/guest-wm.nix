#
#  Window management for the tailvisor macOS guest.
#
#  The physical macbook runs yabai + skhd on the ALT modifier (see
#  darwin/configuration.nix). Inside the VM we run our own yabai + skhd on the
#  CMD + CTRL prefix instead. The host's skhd binds nothing on cmd, so every
#  cmd-family combo passes straight through the VM window to the guest, where
#  this skhd picks it up. No modifier collision, no fighting event taps.
#
#  SIP is disabled in the guest, so yabai's scripting addition IS loaded (same
#  as the physical host). That's what makes space switching instant: native
#  Mission Control slides the desktops (slow on the VM's virtual GPU), whereas
#  `yabai -m space --focus` hard-jumps with no animation at all. The SA also
#  unlocks moving windows across spaces.
#
#  One-time manual step after the first switch: macOS prompts to grant yabai
#  and skhd Accessibility permission (System Settings -> Privacy & Security ->
#  Accessibility). TCC can't be set declaratively — approve both once.
#
{ config, lib, ... }:

{
  config = lib.mkIf config.tailvisor.guest {

    services.yabai = {
      enable = true;
      enableScriptingAddition = true;    # SIP off -> SA loads -> instant spaces
      config = {
        layout = "bsp";
        auto_balance = "on";
        split_ratio = "0.50";
        window_placement = "second_child";
        focus_follows_mouse = "off";
        mouse_follows_focus = "on";
        mouse_action1 = "move";
        mouse_action2 = "resize";
        mouse_drop_action = "swap";
        top_padding = "10";
        bottom_padding = "10";
        left_padding = "10";
        right_padding = "10";
        window_gap = "10";
        external_bar = "all:28:0";   # reserve the top strip for sketchybar
      };
      extraConfig = ''
        # Let macOS system dialogs float instead of being tiled.
        yabai -m rule --add app='^System Settings$' manage=off
        yabai -m rule --add app='^System Information$' manage=off
        yabai -m rule --add app='^Activity Monitor$' manage=off
      '';
    };

    # Leafy-teal window borders — frames every window so it's unmistakable
    # you're in the VM (the host uses its own green/grey borders).
    services.jankyborders = {
      enable = true;
      active_color = "0xff8bd5ca";     # teal for the focused window
      inactive_color = "0xff45605c";   # muted teal for the rest
      width = 8.0;
      hidpi = true;
    };

    services.skhd = {
      enable = true;
      skhdConfig = ''
        # Guest window management — cmd + ctrl prefix (passes through the
        # host's alt-based skhd). Scripting addition is loaded, so space
        # focus / moving windows across spaces work and are instant.

        # Focus window in a direction
        cmd + ctrl - h : yabai -m window --focus west
        cmd + ctrl - j : yabai -m window --focus south
        cmd + ctrl - k : yabai -m window --focus north
        cmd + ctrl - l : yabai -m window --focus east

        # Move (warp) the focused window within the tree
        cmd + shift + ctrl - h : yabai -m window --warp west
        cmd + shift + ctrl - j : yabai -m window --warp south
        cmd + shift + ctrl - k : yabai -m window --warp north
        cmd + shift + ctrl - l : yabai -m window --warp east

        # Instant space switching (the whole point of the SA — no slide anim)
        cmd + ctrl - 1 : yabai -m space --focus 1
        cmd + ctrl - 2 : yabai -m space --focus 2
        cmd + ctrl - 3 : yabai -m space --focus 3
        cmd + ctrl - 4 : yabai -m space --focus 4
        cmd + ctrl - 5 : yabai -m space --focus 5
        cmd + ctrl - 6 : yabai -m space --focus 6
        cmd + ctrl - 7 : yabai -m space --focus 7
        cmd + ctrl - 8 : yabai -m space --focus 8
        cmd + ctrl - 9 : yabai -m space --focus 9
        cmd + ctrl - 0 : yabai -m space --focus 10
        cmd + ctrl - p : yabai -m space --focus prev
        cmd + ctrl - n : yabai -m space --focus next

        # Send the focused window to space N and follow it there. 3 and 4 only
        # work once macOS's clipboard-screenshot hotkeys (⌃⇧⌘3 / ⌃⇧⌘4) are
        # disabled — they sit above skhd's event tap otherwise.
        cmd + shift + ctrl - 1 : yabai -m window --space 1 ; yabai -m space --focus 1
        cmd + shift + ctrl - 2 : yabai -m window --space 2 ; yabai -m space --focus 2
        cmd + shift + ctrl - 3 : yabai -m window --space 3 ; yabai -m space --focus 3
        cmd + shift + ctrl - 4 : yabai -m window --space 4 ; yabai -m space --focus 4
        cmd + shift + ctrl - 5 : yabai -m window --space 5 ; yabai -m space --focus 5
        cmd + shift + ctrl - 6 : yabai -m window --space 6 ; yabai -m space --focus 6
        cmd + shift + ctrl - 7 : yabai -m window --space 7 ; yabai -m space --focus 7
        cmd + shift + ctrl - 8 : yabai -m window --space 8 ; yabai -m space --focus 8
        cmd + shift + ctrl - 9 : yabai -m window --space 9 ; yabai -m space --focus 9
        cmd + shift + ctrl - 0 : yabai -m window --space 10 ; yabai -m space --focus 10

        # Resize the focused window
        cmd + ctrl - left  : yabai -m window --resize left:-60:0 ; yabai -m window --resize right:-60:0
        cmd + ctrl - right : yabai -m window --resize right:60:0 ; yabai -m window --resize left:60:0
        cmd + ctrl - up    : yabai -m window --resize top:0:-60 ; yabai -m window --resize bottom:0:-60
        cmd + ctrl - down  : yabai -m window --resize bottom:0:60 ; yabai -m window --resize top:0:60

        # Layout tweaks
        cmd + ctrl - s : yabai -m window --toggle split
        cmd + ctrl - f : yabai -m window --toggle zoom-fullscreen
        cmd + ctrl - t : yabai -m window --toggle float ; yabai -m window --grid 4:4:1:1:2:2
        cmd + ctrl - e : yabai -m space --balance
        cmd + ctrl - r : yabai -m space --rotate 90
        cmd + ctrl - g : yabai -m space --toggle padding ; yabai -m space --toggle gap

        # Restart the guest WM
        cmd + shift + ctrl - r : launchctl kickstart -k "gui/$(id -u)/org.nixos.skhd" ; launchctl kickstart -k "gui/$(id -u)/org.nixos.yabai"
      '';
    };

  };
}
