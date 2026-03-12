{
  description = "Amgi Ruby development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    ruby-nix = {
      url = "github:inscapist/ruby-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bundix = {
      url = "github:inscapist/bundix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ruby-nix,
    bundix,
    git-hooks,
    ...
  }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      mkPkgs = system:
        import nixpkgs {
          inherit system;
          overlays = [ ruby-nix.overlays.ruby ];
        };
      mkRubyContext =
        system:
        let
          pkgs = mkPkgs system;
          ruby = pkgs.ruby_3_3;
          env = pkgs.bundlerEnv {
            name = "amgi-bundle";
            inherit ruby;
            gemdir = ./.;
            gemset = ./gemset.nix;
          };
          mkRubyCommand =
            name: text:
            pkgs.writeShellApplication {
              inherit name;
              runtimeInputs = [
                env
                ruby
              ];
              inherit text;
            };
          amgiPackage = pkgs.stdenvNoCC.mkDerivation {
            pname = "amgi";
            version = "0.1.0";
            dontUnpack = true;
            installPhase = ''
              mkdir -p $out/bin $out/lib $out/libexec
              cp ${./Gemfile} $out/Gemfile
              cp ${./Gemfile.lock} $out/Gemfile.lock
              cp ${./bin/amgi} $out/libexec/amgi
              cp -R ${./lib}/. $out/lib/
              chmod +x $out/libexec/amgi
              cat > $out/bin/amgi <<EOF
              #!${pkgs.bash}/bin/bash
              set -euo pipefail
              export BUNDLE_IGNORE_CONFIG=1
              export GEM_HOME="${env}/${ruby.gemPath}"
              export GEM_PATH="${env}/${ruby.gemPath}"
              exec ${ruby}/bin/ruby "$out/libexec/amgi" "\$@"
              EOF
              chmod +x $out/bin/amgi
            '';
            meta = {
              mainProgram = "amgi";
              platforms = pkgs.lib.platforms.all;
            };
          };
        in
        {
          inherit pkgs;
          inherit env ruby;
          inherit amgiPackage;
          bundixCli = bundix.packages.${system}.default;
          bundleLock = mkRubyCommand "bundle-lock" ''
            export BUNDLE_IGNORE_CONFIG=1
            export BUNDLE_PATH=vendor/bundle
            exec bundle lock "$@"
          '';
          bundleUpdate = mkRubyCommand "bundle-update" ''
            export BUNDLE_IGNORE_CONFIG=1
            export BUNDLE_PATH=vendor/bundle
            exec bundle lock --update "$@"
          '';
          lintYamlHook = mkRubyCommand "amgi-lint-yaml-hook" ''
            export BUNDLE_IGNORE_CONFIG=1
            exec ruby bin/lint-yaml "$@"
          '';
          lintHook = mkRubyCommand "amgi-lint-hook" ''
            export BUNDLE_IGNORE_CONFIG=1
            exec bin/lint "$@"
          '';
          testHook = mkRubyCommand "amgi-test-hook" ''
            export BUNDLE_IGNORE_CONFIG=1
            exec bin/test "$@"
          '';
        };
    in
    {
      checks = forAllSystems (
        system:
        let
          rubyContext = mkRubyContext system;
        in
        {
          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              amgi-lint-yaml = {
                enable = true;
                name = "Amgi YAML lint";
                entry = "${rubyContext.pkgs.lib.getExe rubyContext.lintYamlHook}";
                always_run = true;
                pass_filenames = false;
              };
              amgi-lint = {
                enable = true;
                name = "Amgi Ruby lint";
                entry = "${rubyContext.pkgs.lib.getExe rubyContext.lintHook}";
                always_run = true;
                pass_filenames = false;
              };
              amgi-test = {
                enable = true;
                name = "Amgi test";
                entry = "${rubyContext.pkgs.lib.getExe rubyContext.testHook}";
                always_run = true;
                pass_filenames = false;
              };
            };
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          rubyContext = mkRubyContext system;
        in
        {
          default = rubyContext.amgiPackage;
          amgi = rubyContext.amgiPackage;
        }
      );

      apps = forAllSystems (
        system: {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/amgi";
            meta = {
              description = "Run the Amgi CLI";
            };
          };
          amgi = {
            type = "app";
            program = "${self.packages.${system}.amgi}/bin/amgi";
            meta = {
              description = "Run the Amgi CLI";
            };
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          rubyContext = mkRubyContext system;
          preCommitCheck = self.checks.${system}.pre-commit-check;
        in
        {
          default = rubyContext.pkgs.mkShell {
            shellHook = ''
              export PATH=${rubyContext.env}/bin:${rubyContext.ruby}/bin:$PATH
              ${preCommitCheck.shellHook}
            '';
            buildInputs = [
              rubyContext.env
              rubyContext.ruby
              rubyContext.bundixCli
              rubyContext.bundleLock
              rubyContext.bundleUpdate
            ] ++ preCommitCheck.enabledPackages;
            BUNDLE_IGNORE_CONFIG = "1";
            AMGI_PRE_COMMIT_CONFIG = preCommitCheck.config.configFile;
          };
        }
      );
    };
}
