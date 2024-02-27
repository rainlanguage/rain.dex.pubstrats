{
  description = "Flake for development workflows.";

  inputs = {
    rainix.url = "github:rainprotocol/rainix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {self, flake-utils, rainix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = rainix.pkgs.${system};
      in {
        packages = rec {
          uniswap-prelude = rainix.mkTask.${system} {
            name = "uniswap-prelude";
            body = ''
              set -euxo pipefail

              FOUNDRY_PROFILE=reference forge build --force
              FOUNDRY_PROFILE=quoter forge build --force
            '';
            additionalBuildInputs = rainix.sol-build-inputs.${system};
          };
        } // rainix.packages.${system};
        devShells = rainix.devShells.${system};
      }
    );

}
