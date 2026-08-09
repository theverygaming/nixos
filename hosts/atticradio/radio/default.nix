{
  config,
  pkgs,
  flakeInputs,
  ...
}:

{
  imports = [
    ./sdrscheduler.nix
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
    sdrs = {
      "v4" = {
        /*
          RTLSDRBlog, Blog V4
          Antenna: Diamond X-30 with LNA
        */
        type = "rtl-sdr";
        serial = "67604236";
        services = [
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
                in
                ''
                  export MQTT_HOST="$(cat $CREDENTIALS_DIRECTORY/mqtt_host)"
                  export MQTT_PORT="$(cat $CREDENTIALS_DIRECTORY/mqtt_port)"
                  export MQTT_USERNAME="$(cat $CREDENTIALS_DIRECTORY/mqtt_username)"
                  export MQTT_PASSWORD="$(cat $CREDENTIALS_DIRECTORY/mqtt_password)"
                  ${rtl_433_mqtt_hass}/bin/rtl_433_mqtt_hass.py --host "$MQTT_HOST" --port "$MQTT_PORT" &
                  ${pkgs.rtl_433}/bin/rtl_433 -f 434M -s 1.024M -F "mqtt://$MQTT_HOST:$MQTT_PORT" -M level -Y autolevel -Y minsnr=5 -g 44.5 -d ":''${RTL_SERIAL}"
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
