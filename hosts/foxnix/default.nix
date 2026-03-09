{
  config,
  pkgs,
  flakeInputs,
  ...
}:

{
  imports = [
    ./nvidia.nix
    ./sound.nix
    ./hardware-configuration.nix # hardware scan results

    ../../common
    ../../users
  ];

  custom.profiles.desktop.enable = true;

  custom.desktop.gnome.enable = true;
  custom.desktop.sway = {
    enable = true;
    monitor_cfg = ''
      output HDMI-A-1 pos 0 0 res 1280x1024
      output DP-2 pos 1280 0 res 1920x1080
      output DP-1 pos 3200 0 res 1920x1080
      workspace 1 output HDMI-A-1
      workspace 2 output DP-2
      workspace 3 output DP-1
      workspace 4 output HDMI-A-1
      workspace 5 output DP-2
      workspace 6 output DP-1
    '';
  };

  custom.public_webserver.enable = true;

  # Bootloader.
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
    grub = {
      efiSupport = true;
      device = "nodev";
    };
  };

  # Kernel config
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking
  networking.hostName = "foxnix";
  networking.networkmanager.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # we do not want xterm
  services.xserver.excludePackages = [ pkgs.xterm ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable touchpad support
  services.libinput.enable = true;

  # To be sorted in seperate file lmao

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  environment.variables = {
    SUDO_PROMPT = "enter your password to the :3 organisation -> ";
    EDITOR = "nano";
  };

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
    enableSSHSupport = true;
  };

  # i just want to build an rpi image...
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  sops.defaultSopsFile = flakeInputs.secrets + "/empty.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  system.stateVersion = "25.05";
}
