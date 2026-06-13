{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dns = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # this is kind of ass honestly
    secrets = {
      url = "git+ssh://git@github.com:/theverygaming/nixos-secrets.git?ref=main";
      flake = false;
    };

    nur_theverygaming = {
      url = "github:theverygaming/nix-repo";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    website_theverygaming = {
      url = "github:theverygaming/website";
    };
  };

  outputs =
    inputs@{ self, ... }:
    {
      colmena =
        let
          allHosts =
            with inputs.nixpkgs.lib;
            (attrNames (filterAttrs (x: type: type == "directory") (builtins.readDir ./hosts)));
        in
        {
          meta = {
            nixpkgs = import inputs.nixpkgs {
              # set to something weird that doesn't apply to the majority
              # of machines just to ensure that nodeNixpkgs is working correctly
              system = "armv7l-linux";
            };
            nodeNixpkgs = (
              with inputs.nixpkgs.lib;
              listToAttrs (
                map (
                  name: nameValuePair name (import (./. + "/hosts/${name}/nixpkgs.nix") { flakeInputs = inputs; })
                ) allHosts
              )
            );
            specialArgs = {
              flakeInputs = inputs;
            };
          };
          defaults =
            { name, ... }:
            {
              imports = [
                (
                  {
                    flakeInputs,
                    config,
                    ...
                  }:

                  {
                    nixpkgs.overlays = [
                      (final: prev: {
                        nur_theverygaming = flakeInputs.nur_theverygaming.packages."${config.nixpkgs.system}";
                      })
                    ];
                    # lib.nixosSystem would set this but: https://github.com/zhaofengli/colmena/issues/60
                    # https://github.com/NixOS/nixpkgs/blob/5223d4097bb2c9e89d133f61f898df611d5ea3ca/flake.nix#L74C19-L74C62
                    nixpkgs.flake.source = inputs.nixpkgs.outPath;
                  }
                )
                ./modules/common
                ./modules/nixos
                ./pkgs/override.nix
                (./. + "/hosts/${name}")
                inputs.home-manager.nixosModules.home-manager
                inputs.disko.nixosModules.disko
                inputs.sops-nix.nixosModules.sops
              ];
            };
        }
        // (with inputs.nixpkgs.lib; listToAttrs (map (x: nameValuePair x { }) allHosts));
      colmenaHive = inputs.colmena.lib.makeHive self.outputs.colmena;
      # nix build .#nixosConfigurations.<name>.config.system.build.vm && ./result/bin/run-<name>-vm
      # nix run github:zhaofengli/colmena -- apply --on ... --verbose --show-trace --build-on-target

      nixosConfigurations = (inputs.colmena.lib.makeHive self.outputs.colmena).nodes;
    };
}
