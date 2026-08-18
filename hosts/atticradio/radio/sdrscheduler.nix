{
  config,
  pkgs,
  lib,
  utils,
  ...
}:

let
  cfg = config.custom.sdr-scheduler;
in
{
  options.custom.sdr-scheduler = with lib; {
    enable = lib.mkEnableOption "Enable SDR scheduler";
    sdrs = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            type = mkOption {
              type = types.enum [ "rtl-sdr" ];
              description = "device type";
            };
            serial = mkOption {
              type = types.str;
              description = "(RTL-SDR only) serial number to identify the device";
            };
            services = mkOption {
              type = types.listOf (
                types.submodule {
                  options = {
                    type = mkOption {
                      type = types.enum [
                        "rtl_tcp"
                        "script"
                        "script_cron"
                      ];
                      description = "service type";
                    };
                    priority = mkOption {
                      type = types.int;
                      description = "service priority, higher values preempt lower values";
                    };

                    rtl_tcp = mkOption {
                      type = types.submodule {
                        options = {
                          port = mkOption {
                            type = types.int;
                            description = "port";
                          };
                        };
                      };
                      description = "RTL-TCP options, only apply with type = rtl_tcp";
                    };

                    script = mkOption {
                      type = types.submodule {
                        options = {
                          name = mkOption {
                            type = types.str;
                            description = "name for the script (determines the service name)";
                          };
                          script = mkOption {
                            type = types.str;
                            description = "shell script to run";
                          };
                          extraServiceConfig = mkOption {
                            type = types.attrsOf utils.systemdUtils.unitOptions.unitOption;
                            default = { };
                            description = "additional systemd service config, for example for loading secrets via LoadCredential";
                          };
                          pollInterval = mkOption {
                            type = types.int;
                            default = 5;
                            description = "Poll interval for the condition in seconds";
                          };
                          runCondition = mkOption {
                            type = types.str;
                            default = ''
                              SHOULD_RUN=true
                            '';
                            description = "some bash logic that sets the variable SHOULD_RUN if the script should be running. Useful if you want a calendar of sorts when the script should be running";
                          };
                        };
                      };
                      description = "Script options, only apply with type = script";
                    };

                    script_cron = mkOption {
                      type = types.submodule {
                        options = {
                          name = mkOption {
                            type = types.str;
                            description = "name for the script (determines the service name)";
                          };
                          script = mkOption {
                            type = types.str;
                            description = "shell script to run";
                          };
                          extraServiceConfig = mkOption {
                            type = types.attrsOf utils.systemdUtils.unitOptions.unitOption;
                            default = { };
                            description = "additional systemd service config, for example for loading secrets via LoadCredential";
                          };
                          onCalendar = mkOption {
                            type = types.listOf types.str;
                            description = "when to trigger the script to run. Syntax described in systemd.time(7)";
                          };
                          accuracy = mkOption {
                            type = types.str;
                            default = "5s";
                            description = "systemd timer accuracy (AccuracySec), e.g. 1s";
                          };
                        };
                      };
                      description = "script cron options, only apply with type = script_cron";
                    };
                  };
                }
              );
            };
          };
        }
      );
      description = "Definition of SDR devices";
    };
  };
  config =
    let
      servicesSort =
        services:
        let
          sorted = lib.lists.sortOn (srv: srv.priority) services;
        in
        (lib.throwIfNot (
          lib.length sorted == lib.length (lib.unique (lib.map (srv: srv.priority) services))
        ) "SDR scheduler: a service priority occurs multiple times" sorted);
      serviceFilter =
        filterfn: servicesSorted:
        (lib.filter (item: filterfn item.srv) (
          lib.lists.imap0 (idx: val: {
            idx = idx;
            srv = val;
          }) servicesSorted
        ));

      serviceSystemdName =
        sdrName: service:
        if service.type == "rtl_tcp" then
          "rtltcp-${sdrName}-${lib.toString service.rtl_tcp.port}-rtl"
        else if service.type == "script" then
          "sdrscript-${sdrName}-${service.script.name}"
        else if service.type == "script_cron" then
          "sdrscriptcron-${sdrName}-${service.script_cron.name}"
        else
          null;
      serviceFullSystemdName = sdrName: service: "${serviceSystemdName sdrName service}.service";
      servicesFullSystemdNames =
        sdrName: services: lib.map (srv: serviceFullSystemdName sdrName srv) services;

      getLowerPrioServices = servicesSorted: selfIdx: lib.lists.take selfIdx servicesSorted;
      getHigherPrioServices = servicesSorted: selfIdx: lib.lists.drop (selfIdx + 1) servicesSorted;

      servicesExecutingCheck =
        serviceFullNames:
        "${config.systemd.package}/bin/systemctl is-active ${lib.concatStringsSep " " serviceFullNames} | grep -qE '^(active|activating|deactivating)$'";

      serviceSystemdDependency =
        sdrName: services: idx:
        let
          servicesSorted = servicesSort services;
          lowerPrioServices = getLowerPrioServices servicesSorted idx;
          higherPrioServices = getHigherPrioServices servicesSorted idx;
        in
        {
          serviceConfig = {
            # conflict with all lower-priority services (stop them when this one starts)
            # we do not use conflicts= because conflicts stops services before ExecConditon runs
            ExecStartPre =
              "+" # run with full privileges
              + (pkgs.writeShellScript "service-exec-start-pre" (
                ""
                + (
                  if lib.length lowerPrioServices != 0 then
                    ''
                      ${config.systemd.package}/bin/systemctl stop ${lib.concatStringsSep " " (servicesFullSystemdNames sdrName lowerPrioServices)}
                    ''
                  else
                    ""
                )
              ));
            # prevent execution if any higher-priority services are active
            ExecCondition =
              "+" # run with full privileges
              + (pkgs.writeShellScript "service-exec-condition" (
                ""
                + (
                  if lib.length higherPrioServices != 0 then
                    ''
                      if ${servicesExecutingCheck (servicesFullSystemdNames sdrName higherPrioServices)}; then
                        exit 1
                      fi
                    ''
                  else
                    ""
                )
              ));
          };
        };
    in
    lib.mkMerge [
      (lib.mkIf cfg.enable {
        hardware.rtl-sdr.enable = true;
      })

      # Service: RTL-TCP
      (lib.mkIf cfg.enable (
        let
          sortedRtlTcpServices = services: serviceFilter (srv: srv.type == "rtl_tcp") (servicesSort services);
        in
        {
          systemd.sockets = lib.concatMapAttrs (
            name: def:
            (lib.listToAttrs (
              lib.map ({ idx, srv }: {
                name = "rtltcp-${name}-${lib.toString srv.rtl_tcp.port}";
                value = {
                  listenStreams = [ "0.0.0.0:${lib.toString srv.rtl_tcp.port}" ];
                  wantedBy = [ "sockets.target" ];
                  socketConfig = {
                    # when the service to be started dies or crashes, we reject connections. Prevents infinite loops
                    FlushPending = "yes";
                  };
                };
              }) (sortedRtlTcpServices def.services)
            ))
          ) cfg.sdrs;

          systemd.services = lib.concatMapAttrs (
            name: def:
            (lib.listToAttrs (
              (lib.map ({ idx, srv }: {
                name = "rtltcp-${name}-${lib.toString srv.rtl_tcp.port}";
                value = {
                  bindsTo = [ (serviceFullSystemdName name srv) ];
                  after = [ (serviceFullSystemdName name srv) ];
                  serviceConfig = {
                    Type = "notify";
                    DynamicUser = true;
                    ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd --connections-max=1 --exit-idle-time=0s 127.0.0.1:${
                      lib.toString (50000 + srv.rtl_tcp.port)
                    }";
                  };
                };
              }) (sortedRtlTcpServices def.services))
              ++ (lib.map ({ idx, srv }: {
                name = serviceSystemdName name srv;
                value = lib.attrsets.recursiveUpdate {
                  unitConfig = {
                    StopWhenUnneeded = true;
                  };
                  serviceConfig = {
                    Type = "simple";
                    DynamicUser = true;
                    SupplementaryGroups = "plugdev"; # to access the RTL
                    KillSignal = "SIGKILL"; # rtl_tcp isn't very... responsive so uuuhhh :P
                    SuccessExitStatus = "SIGKILL"; # lol lmao
                    TimeoutStartSec = "5s";
                    TimeoutStopSec = "5s";
                    ExecStartPost = pkgs.writeShellScript "rtl-healthcheck" ''
                      while ! ${pkgs.net-tools}/bin/netstat -tln | grep :${
                        lib.toString (50000 + srv.rtl_tcp.port)
                      } | grep -q LISTEN; do
                        sleep 0.01
                      done
                    '';
                  };
                  script = ''
                    ${pkgs.rtl-sdr}/bin/rtl_tcp -a 127.0.0.1 -p ${
                      lib.toString (50000 + srv.rtl_tcp.port)
                    } -d ${def.serial}
                  '';
                } (serviceSystemdDependency name def.services idx);
              }) (sortedRtlTcpServices def.services))
            ))
          ) cfg.sdrs;

          networking.firewall.allowedTCPPorts = lib.concatMap (
            def: lib.map ({ idx, srv }: srv.rtl_tcp.port) (sortedRtlTcpServices def.services)
          ) (lib.attrValues cfg.sdrs);
        }
      ))

      # Service: Script
      (lib.mkIf cfg.enable (
        let
          sortedScriptServices = services: serviceFilter (srv: srv.type == "script") (servicesSort services);
        in
        {
          systemd.services = lib.concatMapAttrs (
            name: def:
            (lib.listToAttrs (
              (lib.map ({ idx, srv }: {
                name = "${serviceSystemdName name srv}-watcher";
                value = {
                  serviceConfig = {
                    Type = "simple";
                  };
                  script =
                    let
                      servicesSorted = servicesSort def.services;
                      higherPrioServices = getHigherPrioServices servicesSorted idx;
                      selfFullServiceName = serviceFullSystemdName name srv;
                    in
                    ''
                      while [ true ]; do
                        # do nothing while higher priority services are running
                        if ${
                          if lib.length higherPrioServices != 0 then
                            servicesExecutingCheck (servicesFullSystemdNames name higherPrioServices)
                          else
                            "false"
                        }; then
                          sleep ${lib.toString srv.script.pollInterval}
                          continue
                        fi

                        # check if service should be running
                        ${srv.script.runCondition}

                        # make sure the service is in the right state
                        if [ "$SHOULD_RUN" == "true" ]; then
                          if ! ${servicesExecutingCheck [ selfFullServiceName ]}; then
                            # don't restart a failed unit
                            if ! ${config.systemd.package}/bin/systemctl -q is-failed ${selfFullServiceName}; then
                              ${config.systemd.package}/bin/systemctl start ${selfFullServiceName}
                            fi
                          fi
                        else
                          if ${servicesExecutingCheck [ selfFullServiceName ]}; then
                            ${config.systemd.package}/bin/systemctl stop ${selfFullServiceName}
                          fi
                        fi

                        sleep ${lib.toString srv.script.pollInterval}
                      done
                    '';
                  wantedBy = [ "multi-user.target" ];
                };
              }) (sortedScriptServices def.services))
              ++ (lib.map ({ idx, srv }: {
                name = serviceSystemdName name srv;
                value = lib.attrsets.recursiveUpdate {
                  serviceConfig = {
                    Type = "simple";
                    DynamicUser = true;
                    SupplementaryGroups = "plugdev"; # to access the RTL
                  }
                  // srv.script.extraServiceConfig;
                  script = ''
                    RTL_SERIAL="${def.serial}"
                  ''
                  + srv.script.script;
                } (serviceSystemdDependency name def.services idx);
              }) (sortedScriptServices def.services))
            ))
          ) cfg.sdrs;
        }
      ))

      # Service: script cron
      (lib.mkIf cfg.enable (
        let
          sortedScriptCronServices =
            services: serviceFilter (srv: srv.type == "script_cron") (servicesSort services);
        in
        {
          systemd.timers = lib.concatMapAttrs (
            name: def:
            (lib.listToAttrs (
              (lib.map ({ idx, srv }: {
                name = "${serviceSystemdName name srv}";
                value = {
                  timerConfig = {
                    OnCalendar = srv.script_cron.onCalendar;
                    AccuracySec = srv.script_cron.accuracy;
                  };
                  wantedBy = [ "multi-user.target" ];
                };
              }) (sortedScriptCronServices def.services))
            ))
          ) cfg.sdrs;

          systemd.services = lib.concatMapAttrs (
            name: def:
            (lib.listToAttrs (
              (lib.map ({ idx, srv }: {
                name = serviceSystemdName name srv;
                value = lib.attrsets.recursiveUpdate {
                  serviceConfig = {
                    Type = "simple";
                    DynamicUser = true;
                    SupplementaryGroups = "plugdev"; # to access the RTL
                  }
                  // srv.script_cron.extraServiceConfig;
                  script = ''
                    RTL_SERIAL="${def.serial}"
                  ''
                  + srv.script_cron.script;
                } (serviceSystemdDependency name def.services idx);
              }) (sortedScriptCronServices def.services))
            ))
          ) cfg.sdrs;
        }
      ))
    ];
}
