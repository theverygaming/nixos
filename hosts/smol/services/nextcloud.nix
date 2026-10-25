{ ... }:

{
  containers.nextcloud = {
    autoStart = true;
    config =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        services.nextcloud = {
          enable = true;
          package = pkgs.nextcloud35;
          hostName = "nextcloud.smol.lan.m.furrypri.de";
          config.dbtype = "sqlite";
          settings = {
            trusted_proxies = [ "127.0.0.1" ];
            overwriteprotocol = "http";
            "overwrite.cli.url" = "http://nextcloud.smol.lan.m.furrypri.de";
            maintenance_window_start = 1;
            log_type = "systemd";
            serverid = 0;
            default_phone_region = "DE";
          };
          phpOptions = {
            "opcache.interned_strings_buffer" = 16;
          };
        };

        services.nginx.virtualHosts."${config.services.nextcloud.hostName}" = {
          listen = [
            {
              addr = "127.0.0.1";
              port = 50000;
            }
          ];

          extraConfig = ''
            real_ip_header X-Forwarded-For;
            set_real_ip_from 127.0.0.1;
          '';
        };

        system.stateVersion = "26.05";
      };
  };
}
