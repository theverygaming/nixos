{
  flakeInputs,
  pkgs,
  config,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix

    ../../common
    ../../users
    ./services
  ];

  custom.profiles.server.enable = true;

  deployment = {
    targetHost = "smol.lan.m.furrypri.de";
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

  # WireGuard tunnel for Backup to w
  sops.secrets.backupw_wgprvkey = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/backupw.yaml";
    key = "wgprvkey";
  };
  sops.secrets.backupw_wgpubkey = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/backupw.yaml";
    key = "wgpubkey";
  };
  sops.secrets.backupw_wgendpoint = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/backupw.yaml";
    key = "wgendpoint";
  };
  networking.wireguard.enable = true;
  networking.wireguard.interfaces."backupw" = {
    ips = [ "172.20.0.2/30" ];
    privateKeyFile = "${config.sops.secrets.backupw_wgprvkey.path}";
    peers = [
      {
        name = "backupw1";
        publicKey = "$(cat ${config.sops.secrets.backupw_wgpubkey.path})";
        endpoint = "$(cat ${config.sops.secrets.backupw_wgendpoint.path})";
        allowedIPs = [ "172.20.0.1/32" ];
      }
    ];
  };

  # Networking
  networking.hostName = "smol";
  networking.networkmanager.enable = true;

  system.stateVersion = "26.05";
}
