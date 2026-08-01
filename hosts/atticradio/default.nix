{ flakeInputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    ../../common
    ../../users
  ];

  custom.profiles.server.enable = true;

  deployment = {
    targetHost = "atticradio.lan.m.furrypri.de";
    targetPort = 2222;
    targetUser = "root";
  };

  boot.loader = {
    efi = {
      canTouchEfiVariables = false;
      efiSysMountPoint = "/boot/efi";
    };
    systemd-boot.enable = true;
  };

  sops.defaultSopsFile = flakeInputs.secrets + "/empty.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Networking
  networking.hostName = "atticradio";
  networking.networkmanager.enable = true;

  system.stateVersion = "26.05";
}
