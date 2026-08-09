{ config, pkgs, ... }:

{
  imports = [
    ./sdrscheduler.nix
  ];

  custom.sdr-scheduler = {
    enable = true;
    sdrs = {
      "qfh" = {
        /*
          Realtek, RTL2838UHIDIR, nooelec nesdr SMArt
          Antenna: 137Mhz QFH
        */
        type = "rtl-sdr";
        serial = "37063354";
      };

      "logped" = {
        /*
          Realtek, RTL2838UHIDIR, generic, missing case (taped :P)
          Antenna: logperiodic
        */
        type = "rtl-sdr";
        serial = "89612941";
      };

      "v4" = {
        /*
          RTLSDRBlog, Blog V4
          Antenna: Diamond X-30 with LNA
        */
        type = "rtl-sdr";
        serial = "67604236";
        services = [
          {
            type = "script";
            priority = 0;
            script = {
              name = "rtl_433";
              script = ''
                ${pkgs.rtl_433}/bin/rtl_433 -f 433.92M -s 1.024M -d ":''${RTL_SERIAL}"
              '';
              runCondition = ''
                if [ $((($(date +%s) / 60) % 2)) == 0 ]; then
                  SHOULD_RUN=true
                else
                  SHOULD_RUN=false
                fi
              '';
            };
          }
          {
            type = "script_cron";
            priority = 1;
            script_cron = {
              name = "kalibrate-rtl";
              script = ''
                DEVIDX="$(${pkgs.rtl-sdr}/bin/rtl_test -d -1 2>&1 | grep "''${RTL_SERIAL}" | ${pkgs.gawk}/bin/awk '{print $1}' | tr -d ':' | tr -d '[:space:]')"
                # kalibrate-rtl needs HOME set, otherwise it'll crash :)
                export HOME=/tmp
                ${pkgs.kalibrate-rtl}/bin/kal -b GSM900 -c 5 -d "''${DEVIDX}"
              '';
              onCalendar = [
                "*-*-* *:*:15"
                "*-*-* *:*:45"
              ];
            };
          }
          {
            type = "rtl_tcp";
            priority = 2;
            rtl_tcp.port = 1234;
          }
          {
            type = "rtl_tcp";
            priority = 3;
            rtl_tcp.port = 1235;
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
      };
    };
  };
}
