{
  description = "";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; let
            pythonWithPackages = python3.withPackages (p:
              with p; [
                pyserial
                pillow
                numpy
                numba
                opencv4
                pymunk
                bdffont
                pillow
              ]);
          in [
            pythonWithPackages
            usb-reset
          ];
        };
      }
    );
}
