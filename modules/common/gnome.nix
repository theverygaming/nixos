{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.desktop.gnome;
in
{
  options.custom.desktop.gnome = {
    enable = lib.mkEnableOption "Enable GNOME desktop";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Enable the GNOME Desktop Environment.
      services.displayManager.gdm.enable = true;
      services.desktopManager.gnome.enable = true;

      environment.gnome.excludePackages = (
        with pkgs;
        [
          gnome-tour
          gnome-photos
          cheese # webcam tool
          gnome-terminal
          epiphany # web browser
          geary # email reader
          evince # document viewer
          totem # video player
          gnome-calculator
          gnome-calendar
          gnome-music
          tali # poker game
          iagno # go game
          hitori # sudoku game
          atomix # puzzle game
          gnome-maps
          gnome-contacts
          gnome-clocks
          gnome-weather
        ]
      );

      home-manager.sharedModules = [
        (
          {
            pkgs,
            lib,
            config,
            ...
          }:
          let
            cfg = config.custom.desktop.gnome;
          in
          {
            home.packages =
              with pkgs.gnomeExtensions;
              [
                appindicator
                runcat
                clipboard-indicator
              ]
              ++ (with pkgs; [
                gnome-boxes # VNC etc. tool
                xfce4-terminal
              ]);

            dconf.settings = {
              "org/gnome/shell" = {
                disable-user-extensions = false;
                enabled-extensions = [
                  "appindicatorsupport@rgcjonas.gmail.com"
                  "runcat@kolesnikov.se"
                  "clipboard-indicator@tudmotu.com"
                ];
              };

              "org/gnome/shell/extensions/appindicator" = {
                tray-pos = "right";
              };

              "org/gnome/shell/extensions/runcat" = {
                idle-threshold = 5; # give them some eepy time (THANK CH4!!!, now kitty eepy,,,)
                displaying-items = "character-and-percentage";
              };

              "org/gnome/desktop/interface" = {
                color-scheme = "prefer-dark"; # gtk4 scheme (gtk3 set below)
                clock-show-seconds = true;
              };

              # enable minimize, maximize buttons
              "org/gnome/desktop/wm/preferences" = {
                button-layout = ":appmenu,minimize,maximize,close";
              };

              # wm tweaks
              "org/gnome/mutter" = {
                edge-tiling = true;
                dynamic-workspaces = true;
              };

              # hell naw to automount and autorun
              # (like ???what this isnt windows)
              "org/gnome/desktop/media-handling" = {
                automount = false;
                automount-open = false;
                autorun-never = true;
              };

              # no i don't want my pc to eep 10 seconds after i leave
              "org/gnome/settings-daemon/plugins/power" = {
                sleep-inactive-ac-timeout = 6000;
              };
              "org/gnome/desktop/session" = {
                idle-delay = lib.hm.gvariant.mkUint32 0;
              };

              # recent files are annoying
              "org/gnome/desktop/privacy" = {
                remember-recent-files = false;
              };

              # MY EYES
              "org/gnome/settings-daemon/plugins/color" = {
                night-light-enabled = true;
                night-light-schedule-automatic = true;
              };

              # favorites
              "org/gnome/shell" = {
                favorite-apps = [
                  "org.gnome.Nautilus.desktop"
                  "firefox.desktop"
                  "google-chrome.desktop"
                  "discord.desktop"
                  "org.telegram.desktop.desktop"
                  "signal-desktop.desktop"
                  "code.desktop"
                  "xfce4-terminal.desktop"
                  "io.github.dimtpap.coppwr.desktop"
                ];
              };

              # touchpad
              "org/gnome/desktop/peripherals/touchpad" = {
                tap-to-click = true;
                natural-scroll = false;
              };

              # mouse
              "org/gnome/desktop/peripherals/mouse" = {
                accel-profile = "flat";
              };

              # keyboard layout and stuff
              "org/gnome/desktop/input-sources" =
                let
                  layouts = [
                    (lib.hm.gvariant.mkTuple [
                      "xkb"
                      "us"
                    ])
                    (lib.hm.gvariant.mkTuple [
                      "xkb"
                      "de"
                    ])
                  ];
                in
                {
                  sources = layouts;
                  mru-sources = layouts; # mru is "most recently used"
                };

              # keybinds
              "org/gnome/shell/keybindings" = {
                show-screenshot-ui = [ "<Shift><Super>s" ]; # windows screenshot keybind
              };
              "org/gnome/settings-daemon/plugins/media-keys" = {
                search = [ "<Super>d" ];
              };

              # keybinds: i3-like windowing stuff
              "org/gnome/desktop/wm/keybindings" = {
                switch-to-workspace-1 = [ "<Super>1" ];
                switch-to-workspace-2 = [ "<Super>2" ];
                switch-to-workspace-3 = [ "<Super>3" ];
                switch-to-workspace-4 = [ "<Super>4" ];
                move-to-workspace-1 = [ "<Super><Shift>1" ];
                move-to-workspace-2 = [ "<Super><Shift>2" ];
                move-to-workspace-3 = [ "<Super><Shift>3" ];
                move-to-workspace-4 = [ "<Super><Shift>4" ];
              };

              # custom keybinds
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
                name = "open terminal";
                command = "xfce4-terminal";
                binding = "<Super>Return";
              };
              "org/gnome/settings-daemon/plugins/media-keys" = {
                custom-keybindings = [
                  "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
                ];
              };

              # desktop background
              "org/gnome/desktop/background" =
                let
                  background = config.custom.desktop.background;
                in
                {
                  picture-uri = "file://${background}";
                  picture-uri-dark = "file://${background}";
                  primary-color = "#000000000000";
                  secondary-color = "#000000000000";
                };
            };

            gtk = {
              enable = true;

              # gtk3 theme
              theme = {
                name = "adw-gtk3-dark";
                package = pkgs.adw-gtk3;
              };
              gtk4.theme = null;
            };
          }
        )
      ];
    })
    {
      home-manager.sharedModules = [
        {
          options.custom.desktop.gnome = { };
        }
      ];
    }
  ];
}
