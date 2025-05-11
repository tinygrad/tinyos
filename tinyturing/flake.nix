{
  description = "python turing usb display driver";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      overlay = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (python-final: python-prev: {
            tinyturing = python-final.callPackage ./default.nix { };
          })
        ];
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs =
            with pkgs;
            let
              pythonWithPackages = python3.withPackages (
                p: with p; [
                  pyserial
                  pillow
                  numpy
                  numba
                  opencv4
                  pymunk
                  bdffont
                  pillow
                ]
              );
            in
            [
              pythonWithPackages
              usb-reset
            ];
        };

        packages.default = pkgs.python3Packages.tinyturing;
      }
    )
    // {
      overlays.default = overlay;
    };
}
