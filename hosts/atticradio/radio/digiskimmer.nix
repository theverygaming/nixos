{
  pkgs,
  config,
  flakeInputs,
  lib,
  ...
}:

let
  digiskimmer = pkgs.python3.pkgs.buildPythonApplication {
    pname = "DigiSkimmer";
    version = "dev";

    src = pkgs.fetchFromGitHub {
      owner = "lazywalker";
      repo = "DigiSkimmer";
      rev = "154b5dfb147c18dd94470ad18a794bdac7c6ab6f";
      sha256 = "sha256-d4dHK+OIzPDuXFObDpc7hP+EA2LvZLAj7i6zQnTHHwA=";
    };

    format = "other";
    dontBuild = true;

    dependencies = with pkgs.python3Packages; [
      numpy
      requests
    ];

    preFixup = ''
      makeWrapperArgs+=( --prefix PATH : "${
        lib.makeBinPath (
          with pkgs;
          [
            wsjtx
          ]
        )
      }")
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/lib
      cp -r digiskr/ lib/* $out/lib
      cp fetch.py $out/bin/digiskimmer

      substituteInPlace $out/bin/digiskimmer --replace-fail \
        "sys.path.append('./lib')" \
        "sys.path.append('$out/lib')"
      substituteInPlace $out/bin/digiskimmer --replace-fail \
        "from digiskr import Option, Config" \
        "sys.path.append('$out/lib'); from digiskr import Option, Config"

      substituteInPlace $out/lib/digiskr/config.py --replace-fail \
        'import json' \
        'import json; import os'
      substituteInPlace $out/lib/digiskr/config.py --replace-fail \
        'for file in ["/opt/digiskr/settings.py", "./settings.py", "./settings.json"]:' \
        'for file in [os.environ.get("DIGISKR_CONFIG", ""), "/opt/digiskr/settings.py", "./settings.py", "./settings.json"]:'

      runHook postInstall
    '';
  };
in
{
  systemd.services.digiskimmer = {
    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      PrivateTmp = true;
      LoadCredential = [
        "settings.py:${config.sops.secrets.digiskimmer_settings.path}"
      ];
    };
    script = ''
      DIGISKR_CONFIG=$CREDENTIALS_DIRECTORY/settings.py ${digiskimmer}/bin/digiskimmer
    '';
    wantedBy = [ "multi-user.target" ];
  };

  sops.secrets.digiskimmer_settings = {
    sopsFile = flakeInputs.secrets + "/hosts/atticradio/digiskimmer.yaml";
    key = "settings";
    restartUnits = [ "digiskimmer.service" ];
  };
}
