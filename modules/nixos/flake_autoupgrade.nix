{
  config,
  lib,
  flakeInputs,
  ...
}:

let
  cfg = config.custom.flake_auto_upgrade;
in
{
  options.custom.flake_auto_upgrade = {
    enable = lib.mkEnableOption "Enable automatic upgrades for flakes";
    dates = lib.mkOption {
      type = lib.types.str;
      default = "02:00";
      description = ''
        see system.autoUpgrade.dates
      '';
    };
    randomizedDelaySec = lib.mkOption {
      default = "45min";
      type = lib.types.str;
      description = ''
        see system.autoUpgrade.randomizedDelaySec
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      flake = flakeInputs.self.outPath;
      flags = [
        "--no-write-lock-file"
        "--print-build-logs"
      ]
      ++ (lib.concatLists (
        map
          (x: [
            "--update-input"
            x
          ])
          (
            builtins.filter (
              x:
              !builtins.elem x [
                "self"
                "secrets"
              ]
            ) (lib.attrNames flakeInputs)
          )
      ));
      dates = (lib.mkOverride 999) cfg.dates;
      randomizedDelaySec = (lib.mkOverride 999) cfg.randomizedDelaySec;
      allowReboot = true;
      rebootWindow = {
        lower = "02:00";
        upper = "04:00";
      };
    };
  };
}
