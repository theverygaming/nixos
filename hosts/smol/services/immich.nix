{
  flakeInputs,
  config,
  pkgs,
  ...
}:

{
  containers.immich = {
    autoStart = true;
    config =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        services.immich = {
          enable = true;
          host = "localhost";
          port = 50001;
          openFirewall = false;
          mediaLocation = "/var/lib/immich";
          settings = {
            backup.database.enabled = false; # creates a buncha files we don't need since we have our own DB backups!
          };
        };

        # my local network does some DNS blocks, and that includes huggingface, which immich needs to download ML models
        networking.nameservers = [
          "8.8.8.8"
          "1.1.1.1"
        ];
        networking.useHostResolvConf = false;
        services.resolved.enable = true;

        system.stateVersion = "26.05";
      };
  };

  sops.secrets.backupw_borg_immich_sshkey = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/backupw.yaml";
    key = "borg_immich_sshkey";
  };

  sops.secrets.backupw_borg_immich_passphrase = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/backupw.yaml";
    key = "borg_immich_passphrase";
  };

  sops.secrets.backupw_borg_immich_key = {
    sopsFile = flakeInputs.secrets + "/hosts/smol/backupw.yaml";
    key = "borg_immich_key";
  };

  environment.systemPackages = [
    (
      let
        job = config.services.borgbackup.jobs.w-immich;
      in
      pkgs.writeShellApplication {
        name = "borgadmin-w-immich";

        runtimeInputs = [
          config.services.borgbackup.package
        ];

        text = ''
          if [[ "$(whoami)" != "${job.user}" ]]; then
            echo "This script should run as '${job.user}', but you are '$(whoami)'"
            exit 1
          fi
          echo "NOTE: in case a command wants you to specify a repo, try '::'"
          BORG_BASE_DIR="${job.environment.BORG_BASE_DIR}" BORG_KEY_FILE="${job.environment.BORG_KEY_FILE}" BORG_PASSCOMMAND="${job.encryption.passCommand}" BORG_REPO="${job.repo}" borg "$@"
        '';
      }
    )
    (
      let
        job = config.services.borgbackup.jobs.w-immich;
      in
      pkgs.writeShellApplication {
        name = "borgrestore-w-immich";

        runtimeInputs = [
          config.services.borgbackup.package
          pkgs.curl
          pkgs.rsync
        ];

        text = ''
          if [[ "$(whoami)" != "${job.user}" ]]; then
            echo "This script should run as '${job.user}', but you are '$(whoami)'"
            exit 1
          fi

          mkdir -p /tmp/immich_restore && chown ${job.user} /tmp/immich_restore && chmod 700 /tmp/immich_restore
          BORG_BASE_DIR="${job.environment.BORG_BASE_DIR}" BORG_KEY_FILE="${job.environment.BORG_KEY_FILE}" BORG_PASSCOMMAND="${job.encryption.passCommand}" BORG_REPO="${job.repo}" borg mount '::' /tmp/immich_restore
          cleanup() {
            BORG_BASE_DIR="${job.environment.BORG_BASE_DIR}" BORG_KEY_FILE="${job.environment.BORG_KEY_FILE}" BORG_PASSCOMMAND="${job.encryption.passCommand}" BORG_REPO="${job.repo}" borg umount /tmp/immich_restore
            rmdir /tmp/immich_restore
          }
          trap cleanup EXIT

          echo "please choose a backup to restore:"
          ls -laht /tmp/immich_restore
          read -rp "backup to restore: " RESTORE_NAME || true
          if [[ ! -d "/tmp/immich_restore/$RESTORE_NAME/var/lib/nixos-containers/immich/var/lib/immich/" ]]; then
            echo "invalid restore path chosen"
            exit 1
          fi

          echo "your current immich install will be obliterated (not quite, it'll be moved around and you can delete it manually later but still!!) Are you sure? Type 'yea!! do it!!' if you are sure"
          read -rp "confirm: " CONFIRM
          if [[ "$CONFIRM" != "yea!! do it!!" ]]; then
            echo "you did not confirm"
            exit 1
          fi

          MOVE_PATH="/var/lib/nixos-containers/immich.$(date +%s).bak"
          echo "will stop and move old immich to $MOVE_PATH"
          systemctl stop container@immich
          mv /var/lib/nixos-containers/immich "$MOVE_PATH"

          echo "starting immich so it initializes DB etc."
          systemctl start container@immich
          echo "waiting for immich server to come up"
          curl --fail --silent --show-error --retry 120 --max-time 2 --retry-delay 1 --retry-all-errors http://localhost:50001/api/server/ping
          echo "stopping immich again"
          systemd-run -M immich --quiet --pipe --wait /bin/sh -c '. /etc/profile; set -eu; systemctl stop immich-server.service'

          echo "restoring data"
          rm -rf "/var/lib/nixos-containers/immich/var/lib/immich"
          rsync -aP "/tmp/immich_restore/$RESTORE_NAME/var/lib/nixos-containers/immich/var/lib/immich/" "/var/lib/nixos-containers/immich/var/lib/immich/"
          echo "restoring DB"
          systemd-run -M immich --quiet --pipe --wait /bin/sh -c '. /etc/profile; set -eu; su -s /bin/sh postgres -c "set -eu; pg_restore --clean --create --dbname=postgres /var/lib/immich/immich_db_dump_tmp/immich_current.dump"'
          rm -rf "/var/lib/nixos-containers/immich/var/lib/immich/immich_db_dump_tmp"

          echo "starting the restored immich"
          systemd-run -M immich --quiet --pipe --wait /bin/sh -c '. /etc/profile; set -eu; systemctl start immich-server.service'
        '';
      }
    )
  ];

  services.borgbackup.jobs.w-immich = {
    repo = "ssh://m@172.20.0.1/fops/backups/smol/immich";
    doInit = false;
    paths = [
      "/var/lib/nixos-containers/immich/var/lib/immich"
    ];
    environment = {
      BORG_RSH = "ssh -i ${config.sops.secrets.backupw_borg_immich_sshkey.path}";
      BORG_BASE_DIR = "/root";
      BORG_KEY_FILE = config.sops.secrets.backupw_borg_immich_key.path;
    };
    compression = "auto,zstd,5";
    startAt = "*-*-* 02:00:00 UTC";
    persistentTimer = true;
    encryption = {
      mode = "keyfile";
      passCommand = "cat ${config.sops.secrets.backupw_borg_immich_passphrase.path}";
    };
    preHook = ''
      systemd-run -M immich --quiet --pipe --wait /bin/sh -c '. /etc/profile; set -eu; systemctl stop immich-server.service'
      systemd-run -M immich --quiet --pipe --wait /bin/sh -c '. /etc/profile; set -eu; su -s /bin/sh immich -c "set -eu; mkdir -p /var/lib/immich/immich_db_dump_tmp && pg_dump -Fc -U immich -d immich > /var/lib/immich/immich_db_dump_tmp/immich_current.dump"'
      systemctl stop container@immich
    '';
    postHook = ''
      systemctl start container@immich
      systemd-run -M immich --quiet --pipe --wait /bin/sh -c '. /etc/profile; set -eu; rm -rf /var/lib/immich/immich_db_dump_tmp'
    '';
    prune.keep = {
      within = "7d"; # keep absolutely everything within the last week
      daily = 14; # 2 weeks
      weekly = 8; # 2 months
      monthly = 6;
      "3monthly" = 8; # 2 years
      yearly = 8;
    };
  };
}
