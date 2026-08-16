{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.pkggroups.networking;
in
{
  options.custom.pkggroups.networking = {
    enable = lib.mkEnableOption "Enable networking-related packages";
  };

  config = lib.mkIf cfg.enable {
    programs.wireshark.enable = true;
    programs.cnping.enable = true;

    environment.systemPackages = with pkgs; [
      inetutils
      arping
      mtr
      dnsutils
      net-tools
    ];
  };
}
