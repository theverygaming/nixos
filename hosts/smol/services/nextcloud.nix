{ flakeInputs, config, ... }:

{
  sops.secrets.nextcloud_smtp_host = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/nextcloud.yaml";
    key = "smtp_host";
  };

  sops.secrets.nextcloud_smtp_port = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/nextcloud.yaml";
    key = "smtp_port";
  };

  sops.secrets.nextcloud_smtp_username = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/nextcloud.yaml";
    key = "smtp_username";
  };

  sops.secrets.nextcloud_smtp_password = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/nextcloud.yaml";
    key = "smtp_password";
  };

  sops.secrets.nextcloud_mail_from_domain = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/nextcloud.yaml";
    key = "mail_from_domain";
  };

  sops.secrets.nextcloud_mail_from_address = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/nextcloud.yaml";
    key = "mail_from_address";
  };

  containers.nextcloud = {
    autoStart = true;
    bindMounts = {
      "${config.sops.secrets.nextcloud_smtp_host.path}" = {
        hostPath = "${config.sops.secrets.nextcloud_smtp_host.path}";
        isReadOnly = true;
      };
      "${config.sops.secrets.nextcloud_smtp_port.path}" = {
        hostPath = "${config.sops.secrets.nextcloud_smtp_port.path}";
        isReadOnly = true;
      };
      "${config.sops.secrets.nextcloud_smtp_username.path}" = {
        hostPath = "${config.sops.secrets.nextcloud_smtp_username.path}";
        isReadOnly = true;
      };
      "${config.sops.secrets.nextcloud_smtp_password.path}" = {
        hostPath = "${config.sops.secrets.nextcloud_smtp_password.path}";
        isReadOnly = true;
      };
      "${config.sops.secrets.nextcloud_mail_from_domain.path}" = {
        hostPath = "${config.sops.secrets.nextcloud_mail_from_domain.path}";
        isReadOnly = true;
      };
      "${config.sops.secrets.nextcloud_mail_from_address.path}" = {
        hostPath = "${config.sops.secrets.nextcloud_mail_from_address.path}";
        isReadOnly = true;
      };
    };
    config =
      let
        config_ext = config;
      in
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
            mail_smtpauth = true;
            mail_smtpmode = "smtp";
            mail_smtpsecure = "";
          };
          /*
            Whoever invented this module and thought it was a good idea to make it impossible to specify the
            mail_smtp* settings in nextcloud directly (because they are always forcibly overridden)
            GRRRRR *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU*
            *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU*
            *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU* *BITES YOU*

            oh and the nextcloud people who thought it was a good idea to just return error 400 with zero
            fucking reasons provided to the frontend too!

            yeah yeah I kinda get it it should be declarative and all, but come on, not everything in
            nextcloud can even be declarative. Don't force people! Let them *not specify an option and set it non-declaratively*
          */
          secrets = {
            mail_smtphost = config_ext.sops.secrets.nextcloud_smtp_host.path;
            mail_smtpport = config_ext.sops.secrets.nextcloud_smtp_port.path;
            mail_smtpname = config_ext.sops.secrets.nextcloud_smtp_username.path;
            mail_smtppassword = config_ext.sops.secrets.nextcloud_smtp_password.path;
            mail_domain = config_ext.sops.secrets.nextcloud_mail_from_domain.path;
            mail_from_address = config_ext.sops.secrets.nextcloud_mail_from_address.path;
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
