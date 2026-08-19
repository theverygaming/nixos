{
  config,
  pkgs,
  flakeInputs,
  lib,
  ...
}:

{
  imports = [
    ./sdrscheduler.nix
    ./digiskimmer.nix
  ];

  sops.secrets.rtl_433_mqtt_host = {
    sopsFile = flakeInputs.secrets + "/hosts/atticradio/rtl_433.yaml";
    key = "mqtt_host";
  };

  sops.secrets.rtl_433_mqtt_port = {
    sopsFile = flakeInputs.secrets + "/hosts/atticradio/rtl_433.yaml";
    key = "mqtt_port";
  };

  sops.secrets.rtl_433_mqtt_username = {
    sopsFile = flakeInputs.secrets + "/hosts/atticradio/rtl_433.yaml";
    key = "mqtt_username";
  };

  sops.secrets.rtl_433_mqtt_password = {
    sopsFile = flakeInputs.secrets + "/hosts/atticradio/rtl_433.yaml";
    key = "mqtt_password";
  };

  custom.sdr-scheduler = {
    enable = true;
    sdrs =
      let
        getRtlSdrDevIdx = ''
          DEVIDX="$((${pkgs.rtl-sdr}/bin/rtl_test -d -1 || true ) 2>&1 | grep "''${RTL_SERIAL}" | ${pkgs.gawk}/bin/awk '{print $1}' | tr -d ':' | tr -d '[:space:]')"
        '';
      in
      {
        "v4" = {
          /*
            RTLSDRBlog, Blog V4
            Antenna: Diamond X-30 with LNA
          */
          type = "rtl-sdr";
          serial = "67604236";
          services = [
            {
              type = "script_cron";
              priority = 10;
              script_cron = {
                name = "powerspec";
                script = ''
                  set -eu -o pipefail

                  ${getRtlSdrDevIdx}

                  ${pkgs.rtl-sdr}/bin/rtl_power -d "''${DEVIDX}" -T -c 0.3 -g 28.0 -f 25M:900M:2k -i 60 -1 /tmp/tmpspec.csv
                  cat /tmp/tmpspec.csv >> "''${STATE_DIRECTORY}/spec-$((($(date '+%s') / 86400) * 86400)).csv"
                  rm /tmp/tmpspec.csv
                '';
                extraServiceConfig = {
                  StateDirectory = "powerspec-rtlv4";
                  PrivateTmp = true;
                };
                onCalendar = [
                  "*-*-* *:00/10:00" # every 10 minutes
                ];
                accuracy = "10s";
              };
            }
            {
              type = "rtl_tcp";
              priority = 100;
              rtl_tcp.port = 1234;
            }
          ];
        };

        "qfh" = {
          /*
            Realtek, RTL2838UHIDIR, nooelec nesdr SMArt
            Antenna: 137Mhz QFH
          */
          type = "rtl-sdr";
          serial = "37063354";
          services = [
            {
              type = "rtl_tcp";
              priority = 100;
              rtl_tcp.port = 1235;
            }
          ];
        };

        "logped" = {
          /*
            Realtek, RTL2838UHIDIR, generic, missing case (taped :P)
            Antenna: logperiodic
          */
          type = "rtl-sdr";
          serial = "89612941";
          services = [
            {
              type = "rtl_tcp";
              priority = 100;
              rtl_tcp.port = 1236;
            }
          ];
        };

        "433" = {
          /*
            Realtek, RTL2838UHIDIR, generic
            Antenna: Diamond SG-M507
          */
          type = "rtl-sdr";
          serial = "72977076";
          services = [
            {
              type = "script";
              priority = 0;
              script = {
                name = "rtl_433";
                script =
                  let
                    rtl_433_mqtt_hass = pkgs.stdenv.mkDerivation {
                      name = "rtl_433_mqtt_hass";
                      src = pkgs.rtl_433.src;

                      propagatedBuildInputs = [
                        (pkgs.python3.withPackages (
                          ps: with ps; [
                            paho-mqtt
                          ]
                        ))
                      ];

                      installPhase = ''
                        mkdir -p $out/bin
                        cp examples/rtl_433_mqtt_hass.py $out/bin/rtl_433_mqtt_hass.py
                      '';
                    };
                    rtl_433_patched = pkgs.rtl_433.overrideAttrs (old: rec {
                      # mqtt won't work with file input: https://github.com/merbanan/rtl_433/issues/2761
                      postPatch = ''
                        substituteInPlace src/rtl_433.c --replace-fail \
                        'sdr_callback(test_mode_buf, n_read, cfg);' \
                        'sdr_callback(test_mode_buf, n_read, cfg); mg_mgr_poll(cfg->mgr, 0);'
                      '';
                    });
                  in
                  ''
                    set -eu -o pipefail

                    ${getRtlSdrDevIdx}

                    export MQTT_HOST="$(cat $CREDENTIALS_DIRECTORY/mqtt_host)"
                    export MQTT_PORT="$(cat $CREDENTIALS_DIRECTORY/mqtt_port)"
                    export MQTT_USERNAME="$(cat $CREDENTIALS_DIRECTORY/mqtt_username)"
                    export MQTT_PASSWORD="$(cat $CREDENTIALS_DIRECTORY/mqtt_password)"

                    ${rtl_433_mqtt_hass}/bin/rtl_433_mqtt_hass.py --host "$MQTT_HOST" --port "$MQTT_PORT" &

                    ${pkgs.rtl-sdr}/bin/rtl_sdr -s 1.024M -f 434.2M -g 44.5 -d "''${DEVIDX}" - | \
                      ${pkgs.csdr}/bin/csdr convert_u8_f | \
                      ${pkgs.csdr}/bin/csdr shift_addition_cc "${lib.toString ((434.2e6 - 433.9e6) / 1.024e6)}" | \
                      ${pkgs.csdr}/bin/csdr fir_decimate_cc 4 0.05 HAMMING | \
                      ${pkgs.csdr}/bin/csdr convert_f_u8 | \
                      ${rtl_433_patched}/bin/rtl_433 \
                        -f 433.9M -r - -s 256k \
                        -F "mqtt://$MQTT_HOST:$MQTT_PORT" \
                        -C si \
                        -M level -M noise:30 \
                        -Y autolevel -Y magest -Y minsnr=6
                  '';
                extraServiceConfig = {
                  LoadCredential = [
                    "mqtt_host:${config.sops.secrets.rtl_433_mqtt_host.path}"
                    "mqtt_port:${config.sops.secrets.rtl_433_mqtt_port.path}"
                    "mqtt_username:${config.sops.secrets.rtl_433_mqtt_username.path}"
                    "mqtt_password:${config.sops.secrets.rtl_433_mqtt_password.path}"
                  ];
                };
              };
            }
            {
              type = "rtl_tcp";
              priority = 100;
              rtl_tcp.port = 1237;
            }
          ];
        };
      };
  };
}
