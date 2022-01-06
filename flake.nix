{
  description = "fteqw-sv";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    let
      supportedSystems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-linux"
        "x86_64-darwin"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      rec {
        packages.fteqw-sv =
          let
            drv =
              { lib
              , stdenv
              , fetchFromGitHub
              , zlib
              , zip
              , pkg-config
              }:
              let
                system' = stdenv.hostPlatform.system;
                soext = stdenv.hostPlatform.extensions.sharedLibrary;

                target' = {
                  "aarch64-darwin" = { target = "macosx"; bits = "arm64"; };
                  "aarch64-linux" = { target = "linux"; bits = "arm64"; };
                  "x86_64-darwin" = { target = "macosx"; bits = "64"; };
                  "x86_64-linux" = { target = "linux"; bits = "64"; };
                }."${system'}" or (throw "Unsupported system ${system'}");

                binname' = "fteqw-${target'.target}-sv${target'.bits}";
              in
              stdenv.mkDerivation rec {
                pname = "fteqw-sv";
                version = "6147";

                # Using their SVN is bad idea, SourceForge is unable to manage theri
                # SVN servers at all (timeouts and random errors)...
                # Luckily FTE team has an official GitHub mirror
                src = fetchFromGitHub {
                  owner = "fte-team";
                  repo = "fteqw";
                  rev = "f612b97fc9d08538af966bda20f92e63b26ae5ca";
                  sha256 = "sha256-GyW1jHxv0lIr0WC2ZjzjMDokwuyEhaeY6chxEerJ2ww=";
                };

                buildInputs = [
                  zlib
                ];

                nativeBuildInputs = [
                  pkg-config
                  zip
                ];

                sourceRoot = "source/engine";
                dontConfigure = true;
                dontStrip = true;

                postPatch = ''
                  substituteInPlace Makefile \
                    --replace "PKGCONFIG=/bin/true" ""

                  substituteInPlace ../plugins/Makefile \
                    --replace "-static-libgcc" "" \
                    --replace "-static-libstdc++" "" \
                    --replace "-R/usr/local/lib" ""

                '' + lib.optionalString stdenv.isDarwin ''
                  substituteInPlace ../plugins/Makefile \
                    --replace "-Wl,--no-undefined" ""
                '';

                makeFlags = [
                  "FTE_TARGET=${target'.target}"
                  "BITS=${target'.bits}"
                  "PKGCONFIG=${pkg-config}/bin/pkg-config"
                  "CC=cc"
                ];

                installPhase = ''
                  runHook preInstall

                  install -D -m 755 release/${binname'} $out/bin/fteqw-sv

                  runHook postInstall
                '';

                buildFlags = [ "sv-rel" ];

                # No official support for aarch64-darwin
                NIX_CFLAGS_COMPILE = lib.optionalString (system' == "aarch64-darwin") (toString [
                  "-Wno-macro-redefined"
                  "-DQ3_LITTLE_ENDIAN"
                  "-DARCH_STRING=arm"
                  "-DDLL_EXT=${soext}"
                ]);
              };
          in
          pkgs.callPackage drv { };
      });
}
