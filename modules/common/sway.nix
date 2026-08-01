{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.desktop.sway;
  swayPackage = (
    pkgs.swayfx.override {
      # HACK: chromium seems to only detect the password store based on the DE
      # "sway" is not one of the DEs it recognizes, so it falls back to "basic_text".
      # We use gnome-keyring (gnome-libsecret) tho, and for it to detect that
      # it's enough to have GNOME in the XDG_CURRENT_DESKTOP list (chromium supports colon-seperated XDG_CURRENT_DESKTOP)
      # I sure hope no other software will randomly explode due to this :sob:
      # https://github.com/chromium/chromium/blob/aab503953a7f271aad675ef8a38f3108d9c2a0f0/components/os_crypt/sync/key_storage_util_linux.cc#L44-L70
      # https://github.com/chromium/chromium/blob/aab503953a7f271aad675ef8a38f3108d9c2a0f0/base/nix/xdg_util.cc#L94-L190
      extraSessionCommands = ''
        export XDG_CURRENT_DESKTOP="$XDG_CURRENT_DESKTOP:GNOME"
      '';
    }
  );
in
{
  options.custom.desktop.sway = {
    enable = lib.mkEnableOption "Enable sway desktop";
    monitor_cfg = lib.mkOption {
      default = "";
      type = lib.types.str;
      description = ''
        sway monitor configuration
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      security.polkit.enable = true;

      services.gnome.gnome-keyring.enable = true;

      # TODO: GTK shall be themed accordingly!

      # TODO: this should be independent from the desktop stuff..
      services.displayManager = {
        gdm = {
          enable = true;
        };
      };

      programs.sway = {
        enable = true;
        package = swayPackage;
        wrapperFeatures.gtk = true;
        extraOptions = [
          "--unsupported-gpu"
        ];
      };

      fonts.packages = [
        pkgs.nerd-fonts.symbols-only
      ];

      home-manager.sharedModules = [
        (
          {
            pkgs,
            lib,
            osConfig,
            config,
            ...
          }:
          let
            background = config.custom.desktop.background;
          in
          {
            home.packages = with pkgs; [
              kitty
              swaybg
              grim
              slurp
              wl-clipboard
            ];

            programs.fuzzel = {
              enable = true;
              settings = {
                main = {
                  terminal = "kitty";
                };
                colors = {
                  background = "323232B0";
                  text = "ffffffff";
                  prompt = "ffffffff";
                  placeholder = "ffffffff";
                  input = "ffffffff";
                  selection = "9b59d0B0";
                  selection-text = "ffffffff";
                };
                border = {
                  selection-radius = 10;
                };
              };
            };

            programs.swaylock = {
              enable = true;
              settings = {
                ignore-empty-password = true;
                show-failed-attempts = true;
                daemonize = true;
                image = toString (
                  pkgs.runCommand "background-blurred" { } ''
                    ${pkgs.imagemagick}/bin/convert ${background} -blur 0x6 $out
                  ''
                );
                scaling = "fill";
                color = "000000";
                show-keyboard-layout = true;
              };
            };

            services.swayidle = {
              enable = true;
              events = {
                before-sleep = "${pkgs.swaylock}/bin/swaylock";
              };
              timeouts = [
                {
                  timeout = 1200;
                  command = "${swayPackage}/bin/swaymsg output \\* dpms off";
                  resumeCommand = "${swayPackage}/bin/swaymsg output \\* dpms on";
                }
                {
                  timeout = 1200;
                  command = "${pkgs.swaylock}/bin/swaylock";
                }
              ];
            };

            wayland.windowManager.sway = {
              enable = true;
              package = swayPackage;
              checkConfig = false; # config check fails with: Cannot create GLES2 renderer: no DRM FD available (probably a swayfx issue?)
              config = rec {
                modifier = "Mod4"; # super key
                terminal = "kitty";
                menu = "fuzzel";
                window.titlebar = false;

                defaultWorkspace = "workspace number 1";

                bars = [
                  {
                    command = "waybar";
                  }
                ];

                input = {
                  "*" = {
                    tap = "enabled"; # tap to click
                  };
                };

                colors = {
                  focused = {
                    background = "#32323266";
                    border = "#9B59D0";
                    childBorder = "#9B59D0";
                    indicator = "#9B59D0";
                    text = "#FFFFFF";
                  };
                };
                gaps = {
                  smartGaps = false;
                  inner = 5;
                };
                keybindings = {
                  # standard stuff (yes, I know home-manager defaults define these - and I could use those - but I do not like a bunch of the defaults sooo uhh :3)
                  "${modifier}+Return" = "exec ${terminal}";
                  "${modifier}+Shift+q" = "kill";
                  "${modifier}+d" = "exec ${menu}";
                  "${modifier}+Left" = "focus left";
                  "${modifier}+Down" = "focus down";
                  "${modifier}+Up" = "focus up";
                  "${modifier}+Right" = "focus right";
                  "${modifier}+Shift+Left" = "move left";
                  "${modifier}+Shift+Down" = "move down";
                  "${modifier}+Shift+Up" = "move up";
                  "${modifier}+Shift+Right" = "move right";
                  "${modifier}+f" = "fullscreen toggle";
                  "${modifier}+s" = "layout stacking";
                  "${modifier}+w" = "layout tabbed";
                  "${modifier}+e" = "layout toggle split";
                  "${modifier}+Shift+space" = "floating toggle";
                  "${modifier}+1" = "workspace number 1";
                  "${modifier}+2" = "workspace number 2";
                  "${modifier}+3" = "workspace number 3";
                  "${modifier}+4" = "workspace number 4";
                  "${modifier}+5" = "workspace number 5";
                  "${modifier}+6" = "workspace number 6";
                  "${modifier}+7" = "workspace number 7";
                  "${modifier}+8" = "workspace number 8";
                  "${modifier}+9" = "workspace number 9";
                  "${modifier}+0" = "workspace number 10";
                  "${modifier}+Shift+1" = "move container to workspace number 1";
                  "${modifier}+Shift+2" = "move container to workspace number 2";
                  "${modifier}+Shift+3" = "move container to workspace number 3";
                  "${modifier}+Shift+4" = "move container to workspace number 4";
                  "${modifier}+Shift+5" = "move container to workspace number 5";
                  "${modifier}+Shift+6" = "move container to workspace number 6";
                  "${modifier}+Shift+7" = "move container to workspace number 7";
                  "${modifier}+Shift+8" = "move container to workspace number 8";
                  "${modifier}+Shift+9" = "move container to workspace number 9";
                  "${modifier}+Shift+0" = "move container to workspace number 10";
                  "${modifier}+Shift+minus" = "move scratchpad";
                  "${modifier}+minus" = "scratchpad show";
                  "${modifier}+Shift+c" = "reload";
                  "${modifier}+Shift+e" =
                    "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'";
                  "${modifier}+r" = "mode resize";

                  # screenshot
                  "${modifier}+Shift+s" = "exec grim -g \"$(slurp)\" - | wl-copy";
                  # lock
                  "${modifier}+l" = "exec swaylock";
                  # help menu (all keybindings)
                  "${modifier}+question" = "exec ${pkgs.writeScript "sway-help" ''
                    #!${pkgs.python3}/bin/python3
                    import pathlib
                    import re

                    with open(pathlib.Path.home() / ".config" / "sway" / "config", "r", encoding="utf-8") as f:
                        cfg = f.read()
                    pattern = re.compile(r"^bindsym ([^ ]+) (.+)$", re.MULTILINE)
                    for m in pattern.finditer(cfg):
                        print(f"{m.group(1)} -> {m.group(2)}")
                  ''} | fuzzel --dmenu --width 100";
                };
                modes = lib.mkOptionDefault {
                  resize = {
                    # let me fuckin toggle the mode with the combo I entered it with??? Why is this not in by default??
                    "${modifier}+r" = "mode default";
                  };
                };
              };

              extraConfig = ''
                output * bg ${background} fill

                blur enable
                blur_passes 3
                blur_radius 2
                blur_noise 0.1
                blur_brightness 1.0
                blur_contrast 1.0
                blur_saturation 1.0

                corner_radius 10

                shadows disable
              ''
              + cfg.monitor_cfg;
            };

            programs.waybar = {
              enable = true;
              settings = {
                mainBar = {
                  layer = "top";
                  position = "top";
                  margin-top = 5;
                  margin-left = 10;
                  margin-right = 10;
                  height = 34;
                  spacing = 0;
                  modules-left = [
                    "sway/workspaces"
                    "sway/mode"
                    "sway/window"
                  ];
                  modules-center = [ "clock" ];
                  modules-right = [
                    "tray"
                    "custom/separator"
                    "pulseaudio"
                    "backlight"
                    "custom/separator"
                    "battery"
                    "temperature"
                    "cpu"
                    "memory"
                    "network"
                    "custom/separator"
                    "custom/power"
                  ];

                  "sway/workspaces" = {
                    disable-scroll = true;
                    all-outputs = true;
                  };

                  "clock" = {
                    format = " {:%Y-%m-%dT%T%z}";
                    interval = 1;
                    tooltip-format = "<tt><small>{calendar}</small></tt>";
                    calendar = {
                      mode = "year";
                      mode-mon-col = 3;
                      weeks-pos = "right";
                      on-scroll = 1;
                      format = {
                        months = "<span color='#ffead3'><b>{}</b></span>";
                        days = "<span color='#ecc6d9'><b>{}</b></span>";
                        weeks = "<span color='#99ffdd'><b>W{}</b></span>";
                        weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                        today = "<span color='#ff6699'><b><u>{}</u></b></span>";
                      };
                    };
                    actions = {
                      on-click-right = "mode";
                      on-scroll-up = "shift_up";
                      on-scroll-down = "shift_down";
                    };
                  };

                  "custom/separator" = {
                    format = "|";
                    interval = "once";
                    tooltip = false;
                  };

                  "cpu" = {
                    interval = 1;
                    format = "{usage:3}%";
                  };

                  "memory" = {
                    interval = 5;
                    format = "{percentage:3}%";
                  };

                  "network" = {
                    interval = 5;
                    format = "󰛳 {bandwidthTotalBits}";
                    format-ethernet = " {bandwidthTotalBits}";
                    format-wifi = "{icon} {bandwidthTotalBits}";
                    format-icons = [
                      "󰤟"
                      "󰤢"
                      "󰤥"
                      "󰤨"
                    ];
                    min-length = 12;
                  };

                  "pulseaudio" = rec {
                    format = "{icon} {volume}% {format_source}";
                    format-bluetooth = "󰥰 {volume}% {format_source}";
                    format-source = " {volume}%";
                    format-icons = [
                      "󰕿"
                      "󰖀"
                      "󰕾"
                    ];
                  };

                  "custom/power" = {
                    format = "⏻";
                    tooltip = false;
                    menu = "on-click";
                    menu-file = pkgs.writeText "waybar-power-menufile" ''
                      <?xml version="1.0" encoding="UTF-8"?>
                      <interface>
                        <object class="GtkMenu" id="menu">
                          <child>
                            <object class="GtkMenuItem" id="lock">
                              <property name="label">Lock</property>
                            </object>
                          </child>
                          <child>
                            <object class="GtkSeparatorMenuItem" id="sep1"/>
                          </child>
                          <child>
                            <object class="GtkMenuItem" id="suspend">
                              <property name="label">Suspend</property>
                            </object>
                          </child>
                          <child>
                            <object class="GtkSeparatorMenuItem" id="sep2"/>
                          </child>
                          <child>
                            <object class="GtkMenuItem" id="reboot">
                              <property name="label">Reboot</property>
                            </object>
                          </child>
                          <child>
                            <object class="GtkMenuItem" id="shutdown">
                              <property name="label">Shutdown</property>
                            </object>
                          </child>
                        </object>
                      </interface>
                    '';
                    menu-actions = {
                      lock = "swaylock";
                      suspend = "systemctl suspend";
                      reboot = "reboot";
                      shutdown = "shutdown";
                    };
                  };
                };
              };
              style = ''
                * {
                  font-family: ${
                    lib.concatStringsSep ", " (
                      map (x: "\"${x}\"") (
                        (
                          if config.fonts.fontconfig.defaultFonts.monospace != [ ] then
                            config.fonts.fontconfig.defaultFonts.monospace
                          else
                            osConfig.fonts.fontconfig.defaultFonts.monospace
                        )
                        ++ [ "Symbols Nerd Font Mono" ]
                      )
                    )
                  };
                }

                window#waybar {
                  background-color: rgba(50, 50, 50, 0.4);
                  color: #ffffff;
                  border-radius: 10px;
                }

                .modules-left, .modules-center, .modules-right {
                  padding: 0 10px;
                }

                .module {
                  margin: 0 5px;
                }

                #custom-separator {
                  color: #9B59D0;
                }
              '';
            };

            home.pointerCursor = {
              name = "macOS";
              package = pkgs.apple-cursor;
              size = 22;
              sway.enable = true;
              x11.enable = true;
              gtk.enable = true;
            };
          }
        )
      ];
    })
    {
      home-manager.sharedModules = [
        {
          options.custom.desktop.sway = { };
        }
      ];
    }
  ];
}
