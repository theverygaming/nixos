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
    basic.enable = lib.mkEnableOption "Enable basic packages for network debugging";
    advanced.enable = lib.mkEnableOption "Enable advanced packages for network debugging (stuff like wireshark)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.basic.enable {
      environment.systemPackages = with pkgs; [
        inetutils
        arping
        mtr
        dnsutils
        net-tools
      ];
    })
    (lib.mkIf cfg.advanced.enable {
      # enable the basic ones too ofc
      custom.pkggroups.networking.basic.enable = lib.mkDefault true;

      programs.wireshark.enable = true;
      programs.cnping.enable = true;
    })
  ];
}
