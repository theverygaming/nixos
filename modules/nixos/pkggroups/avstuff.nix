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
    # silly fix for kdenlive: https://discourse.nixos.org/t/setting-schema-filechooser-is-not-installed-on-some-programs/66091/3
    environment.extraInit = ''
      export XDG_DATA_DIRS="$XDG_DATA_DIRS:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
    '';
  };
}
