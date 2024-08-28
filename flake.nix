{
  description = "Flake for development workflows.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    rainix.url = "github:rainprotocol/rainix";
  };

  outputs = {self, rainix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = rainix.pkgs.${system};
      in rec {
        packages = rec{
          network-list = rainix.network-list.${system};
          networks = pkgs.lib.concatStringsSep " " network-list;

          check-deployer-words = rainix.mkTask.${system} {
            name = "check-deployer-words";
            body = ''
              for network in ${networks}
              do
                echo "Checking deployer words for $network"
                cargo run --manifest-path ''${MANIFEST_PATH} --package rain_orderbook_cli words -c ''${SETTINGS_PATH} -d "$network" --stdout
              done
            '';
          };
        } // rainix.packages.${system};

        devShells.default = pkgs.mkShell {
          packages = [
            packages.check-deployer-words
          ];

          shellHook = rainix.devShells.${system}.default.shellHook;
          buildInputs = rainix.devShells.${system}.default.buildInputs;
          nativeBuildInputs = rainix.devShells.${system}.default.nativeBuildInputs;
        };

      }
    );

}