{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.pkggroups.radio;
in
{
  options.custom.pkggroups.radio = {
    enable = lib.mkEnableOption "Enable Radio-related packages";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      sdrpp
      zenity # required by SDR++ for file dialogs

      /*
        (pkgs.satdump.overrideAttrs (old: {
          src = fetchFromGitHub {
            owner = "SatDump";
            repo = "SatDump";
            rev = "63d3cd96c44134e2d4a47220fb5f53d60bbdb6ce";
            hash = "sha256-nadIgs9fxnxZf5HrW+WdV/qSWxBbaBNlrVxRswUSlMs=";
          };
          patches = [ ];
          postPatch = "";
        }))
      */
      satdump

      nur_theverygaming.vlfrx-tools
      gnuplot # for plotting output from vlfrx-tools
      nur_theverygaming.ebnaut
      nur_theverygaming.ebsynth
    ];

    hardware.rtl-sdr.enable = lib.mkDefault true;
  };
}
