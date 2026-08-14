{ flakeInputs, config, ... }:

{
  networking.firewall.allowedTCPPorts = [
    6697 # IRC
  ];

  services.soju = {
    enable = true;
    adminSocket.enable = false; # the admin socket is in essence just needed once for initial setup of the first admin user. It is also annoying on NixOS as you need to pass -config to the sojudb tool pointing to the config in the nix store.
    listen = [
      "ircs://0.0.0.0:6697"
    ];
    enableMessageLogging = false; # enableMessageLogging stores in the text format, we wanna store in DB. See extraConfig
    extraConfig = ''
      db sqlite3 /var/lib/soju/soju.db
      message-store db
    '';
    hostName = "m.furrypri.de";
    tlsCertificate = "/run/credentials/soju.service/tls_cert";
    tlsCertificateKey = "/run/credentials/soju.service/tls_key";
  };

  sops.secrets.soju_tls_cert = {
    sopsFile = flakeInputs.secrets + "/hosts/vps-1/soju.yaml";
    key = "tls_cert";
  };

  sops.secrets.soju_tls_key = {
    sopsFile = flakeInputs.secrets + "/hosts/vps-1/soju.yaml";
    key = "tls_key";
  };

  systemd.services.soju.serviceConfig = {
    LoadCredential = [
      "tls_key:${config.sops.secrets.soju_tls_key.path}"
      "tls_cert:${config.sops.secrets.soju_tls_cert.path}"
    ];
  };
}
