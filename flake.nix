{
  description = "A language server (LSP) for the Coq theorem prover";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt.url = "github:numtide/treefmt-nix";

    napalm.url = "github:nix-community/napalm";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    treefmt,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
      imports = [treefmt.flakeModule ./editor/code/flakeModule.nix];

      perSystem = {
        config,
        pkgs,
        lib,
        ...
      }: let
        l = lib // builtins;
        coqpkg = pkgs.coqPackages_8_20;
        coqPackages = coqpkg.coqPackages;
        ocamlPackages = coqpkg.coq.ocamlPackages;
        dune = pkgs.dune_3.overrideAttrs (_: rec {
          version = "3.23.1";
          src = pkgs.fetchurl {
            url = "https://github.com/ocaml/dune/releases/download/${version}/dune-${version}.tbz";
            hash = "sha256-k7TnFX9rqP62HPxfhgCO/SxZA3unigF9krSr8wYyNI8=";
          };
        });
        wasmClang = pkgs.writeShellScriptBin "wasm-clang" ''
          exec ${pkgs.llvmPackages_12.clang-unwrapped}/bin/clang \
            -B${pkgs.llvmPackages_12.lld}/bin \
            -resource-dir=${pkgs.llvmPackages_12.clang-unwrapped.lib}/lib/clang/${pkgs.llvmPackages_12.clang-unwrapped.version} \
            --sysroot=${pkgs.pkgsCross.wasi32.wasilibc.dev} \
            -isystem ${pkgs.pkgsCross.wasi32.wasilibc.dev}/include \
            "$@"
        '';
      in {
        packages.default = config.packages.coq-lsp;

        packages.coq-lsp = ocamlPackages.buildDunePackage {
          duneVersion = "3";

          pname = "coq-lsp";
          version = "${self.lastModifiedDate}+8.20-rc1";

          src = self.outPath;

          nativeBuildInputs = l.attrValues {
            inherit (ocamlPackages) menhir;
          };

          propagatedBuildInputs = l.attrValues {
            inherit
              (ocamlPackages)
              cmdliner
              findlib
              ppx_deriving
              ppx_deriving_yojson
              ppx_import
              ppx_sexp_conv
              ppx_hash
              sexplib
              yojson
              zarith
              uri
              dune-build-info
              ppx_inline_test
              logs
              lwt
              tyxml
              ;
          };
        };

        treefmt.config = {
          projectRootFile = "dune-project";

          flakeFormatter = true;

          settings.global.excludes = ["./vendor/**" "lsp-server/jsoo/js_stub/**" "lsp-server/wasm/**"];

          programs.alejandra.enable = true;
          programs.ocamlformat = {
            enable = true;
            configFile = ./.ocamlformat;
          };
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [config.packages.coq-lsp];
          WASM_CC = "${wasmClang}/bin/wasm-clang";

          packages = l.attrValues {
            inherit dune;
            inherit (config.treefmt.build) wrapper;
            inherit (pkgs) nodejs dune-release;
            inherit (ocamlPackages) ocaml ocamlformat ocaml-lsp;
          };
        };
      };
    };
}
