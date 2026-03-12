{
  description = "Amgi Ruby development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { nixpkgs, ... }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          ruby = pkgs.ruby_3_3;
        in {
          default = pkgs.mkShell {
            packages = [
              ruby
              pkgs.bundler
              pkgs.rubyPackages.rspec
              pkgs.rubyPackages.rubocop
              pkgs.rubyPackages."rubocop-performance"
            ];
          };
        }
      );
    };
}
