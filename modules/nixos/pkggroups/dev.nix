{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.pkggroups.dev;
in
{
  options.custom.pkggroups.dev = {
    enable = lib.mkEnableOption "Enable software development packages";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gh # GitHub CLI
      git
      python314
      clang-tools # for clangd
      (vscode-with-extensions.override {
        vscodeExtensions =
          with vscode-extensions;
          [
            llvm-vs-code-extensions.vscode-clangd
            jnoortheen.nix-ide
            twxs.cmake
            gruntfuggly.todo-tree
            mhutchie.git-graph
            ms-vscode.hexeditor
            ms-vscode-remote.remote-ssh
            ms-vscode-remote.remote-containers
            # ms-python.python Broken - 2024-09-15
            mshr-h.veriloghdl
            yzhang.markdown-all-in-one
            ritwickdey.liveserver
            vue.volar
            marp-team.marp-vscode # Markdown presentation tool
          ]
          ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
            {
              name = "vscode-scl";
              publisher = "Gunders89";
              version = "0.0.21";
              sha256 = "sha256-mPiwieHGeSJNAU88X59AlmEYS5Jy3UFA3h85RNMwBn0=";
            }
            {
              name = "discord-vscode";
              publisher = "icrawl";
              version = "5.8.0";
              sha256 = "sha256-IU/looiu6tluAp8u6MeSNCd7B8SSMZ6CEZ64mMsTNmU=";
            }
            {
              name = "vscode-mlir";
              publisher = "llvm-vs-code-extensions";
              version = "0.0.11";
              sha256 = "sha256-slu3Ri8U0ZthHidmd18jcmogPudzvXxqhpmo8AWmsvw=";
            }
            #{
            #  name = "vscode-latex";
            #  publisher = "mathematic";
            #  version = "1.3.0";
            #  sha256 = "sha256-/mbMpel9JHmSh0GN/wIbFi/0voaQBxGn0SueZlUFZUc=";
            #}
            {
              name = "mako";
              publisher = "tommorris";
              version = "0.2.0";
              sha256 = "sha256-Ss5s2fTY+Q/09LQpNWaaYboUgzouJ7OnjJBKtPkonm8=";
            }
            {
              name = "vscode-lark";
              publisher = "dirk-thomas";
              version = "0.1.0";
              sha256 = "sha256-uIXQsi+p3N+Yqzf5quYciv3t4PiK9EN1nwFiH+WHHz8=";
            }
          ];
      })
      verible # verilog formatting
      nixpkgs-fmt # nix formatting
      cartero # cool GTK API testing tool
    ];
    custom.pkggroups.containerization.enable = lib.mkDefault true; # for devcontainers
  };
}
