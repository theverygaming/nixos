{ flakeInputs }:

let
  zone_common = (
    with flakeInputs.dns.lib.combinators;
    {
      TTL = 300;
      SOA = {
        nameServer = "ns1.theverygaming.furrypri.de.";
        adminEmail = "m@screee.ee";
        serial = 2026021701; # The recommended syntax is YYYYMMDDnn (YYYY=year, MM=month, DD=day, nn=revision number
        refresh = 60 * 60;
        retry = 60 * 30;
        expire = 60 * 60 * 24;
      };

      CAA = letsEncrypt "m@screee.ee";
    }
  );
in
{
  getZone =
    zone:
    builtins.getAttr zone {
      "m.furrypri.de" = (
        with flakeInputs.dns.lib.combinators;
        {
          A = [
            "159.69.26.5"
          ];
          AAAA = [
            "2a01:4f8:1c1b:c957::1"
          ];
        }
        // zone_common
      );
      "theverygaming.furrypri.de" = (
        with flakeInputs.dns.lib.combinators;
        {
          A = [
            "159.69.26.5"
          ];
          AAAA = [
            "2a01:4f8:1c1b:c957::1"
          ];

          subdomains = {
            # website, HTTP edition
            "http" = {
              A = [
                "159.69.26.5"
              ];
              AAAA = [
                "2a01:4f8:1c1b:c957::1"
              ];
            };

            "ns1" = {
              A = [
                "159.69.26.5"
              ];
              AAAA = [
                "2a01:4f8:1c1b:c957::1"
              ];
            };

            # FIXME: this is ass, refine DNS
            "infra" = {
              subdomains = {
                "lan" = {
                  subdomains = {
                    "amdE350" = {
                      A = [
                        "192.168.178.39"
                      ];
                    };
                  };
                };
                "vps-1" = {
                  A = [
                    "159.69.26.5"
                  ];
                  AAAA = [
                    "2a01:4f8:1c1b:c957::1"
                  ];
                };
                "vps-old" = {
                  A = [
                    "128.140.1.26"
                  ];
                };
              };
            };
          };
        }
        // zone_common
      );
    };
}
