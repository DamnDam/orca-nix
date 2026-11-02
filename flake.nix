{
  description = "Nix flake for the Orca agentic development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      nixpkgs,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          orca = pkgs.callPackage ./pkgs/orca { };
        in
        {
          default = orca;
          inherit orca;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          orca = pkgs.callPackage ./pkgs/orca { };
        in
        {
          default = {
            type = "app";
            program = "${orca}/bin/orca";
            meta.description = "Run Orca";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              jq
              nixfmt
              shellcheck
            ];
          };
        }
      );

      overlays.default = final: _prev: {
        orca = final.callPackage ./pkgs/orca { };
      };
    };
}
