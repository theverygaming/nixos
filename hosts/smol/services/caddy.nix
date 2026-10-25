{ flakeInputs, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [
    80 # HTTP
    #443 # HTTPS
  ];

  services.caddy = {
    enable = true;
    virtualHosts = {
      "http://nextcloud.smol.lan.m.furrypri.de".extraConfig = ''
        reverse_proxy 127.0.0.1:50000
      '';
    };
  };
}
