{ ... }:

{
  imports = [
    ./profiles
    ./pkggroups
    ./public_webserver.nix
    ./flake_autoupgrade.nix
    ./systemd_discord_notif.nix
  ];
}
