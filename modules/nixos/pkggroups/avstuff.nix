{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.pkggroups.avstuff;
in
{
  options.custom.pkggroups.avstuff = {
    enable = lib.mkEnableOption "Enable A/V recording & editing packages";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      obs-studio
      kdePackages.kdenlive
      audacity
    ];
  };
}
