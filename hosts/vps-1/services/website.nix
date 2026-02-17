{
  flakeInputs,
  pkgs,
  config,
  ...
}:

{
  networking.firewall.allowedTCPPorts = [
    80 # HTTP
    443 # HTTPS
  ];

  services.caddy = {
    enable = true;
    virtualHosts =
      let
        website_built =
          flakeInputs.website_theverygaming.packages."${config.nixpkgs.system}".theverygaming-website;
        # the nix store forces dates to be on the epoch which terribly breaks Caddys Last-Modified header.
        # So we use ETag based on the store path instead
        caddy_etag_hack = ''
          header {
              ETag "${builtins.hashString "sha256" (builtins.baseNameOf website_built)}"
              -Last-Modified
          }
        '';
        website_conf = ''
          root * ${website_built}
          ${caddy_etag_hack}
          file_server
          handle_errors {
              @404 {
                  expression {http.error.status_code} == 404
              }
              rewrite @404 /err/404.html
              file_server
              ${caddy_etag_hack}
          }
        '';
      in
      {
        "m.furrypri.de".extraConfig = ''
          redir https://theverygaming.furrypri.de
        '';

        "http://http.theverygaming.furrypri.de".extraConfig = website_conf;
        "theverygaming.furrypri.de".extraConfig = website_conf;

        "http://".extraConfig = ''
          header Content-Type text/html
          respond <<HTML
              <!DOCTYPE html>
              <html>
                <!-- :3 -->
                <head>
                  <title>:3</title>
                  <meta http-equiv="Refresh" content="5; URL=https://www.youtube-nocookie.com/embed/75KlCpeLo64?si=EgII1K2HQxFhbQUH" />
                  <style>
                  h1 {
                    margin: 0;
                    padding: 0;
                    white-space: nowrap;
                    font-family: monospace;
                    font-size: calc(100vw / .625 / 9);
                  }
                  </style>
                </head>
                <body>
                  <h1>:3</h1>
                </body>
              </html>
          HTML 200
        '';
      };
  };
}
