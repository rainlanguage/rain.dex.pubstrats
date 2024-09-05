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
              set -euxo pipefail

              dotrain_folder_path=''${DOTRAIN_FOLDER_PATH:-.}

              dotrain_paths=""
              for folder in "$dotrain_folder_path"/*; do
                  if [ -d "$folder" ]; then
                      dotrain=$(find "$folder" -type f -name "*.rain" -print)
                      dotrain_paths+=" $dotrain"
                  fi
              done

              for dotrain in "$dotrain_folder_path"/*.rain ; do
                  dotrain_paths+=" $dotrain"
              done

              dotrain_paths=$(echo "$dotrain_paths" | tr -s ' ' | sed 's/^ //;s/ $//')

              for dotrain in $dotrain_paths
              do
                echo "Checking deployments within $dotrain"
                deployment_keys=$(cargo run --manifest-path ''${MANIFEST_PATH} --package rain_orderbook_cli order keys -f $dotrain ''${SETTINGS_PATH:+-c "''${SETTINGS_PATH}"})
                for key in $deployment_keys
                do
                  echo "key: $key"
                  cargo run --manifest-path ''${MANIFEST_PATH} --package rain_orderbook_cli words -f $dotrain ''${SETTINGS_PATH:+-c "''${SETTINGS_PATH}"} --deployment "$key" --stdout
                done
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
