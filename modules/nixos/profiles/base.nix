{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.profiles.base;
in
{
  options.custom.profiles.base = {
    enable = lib.mkEnableOption "Enable Base profile";
  };

  config = lib.mkIf cfg.enable {
    custom.pkggroups = {
      core.enable = lib.mkDefault true;
      networking.basic.enable = lib.mkDefault true;
    };

    # TODO: fail2ban maybe?
    services.openssh = {
      enable = lib.mkDefault true;
      ports = lib.mkDefault [
        2222
      ];
      settings.PasswordAuthentication = lib.mkDefault false; # aw hell nah
    };
  };
}
