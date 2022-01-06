{ lib, stdenv, coreutils, bubblewrap, rlwrap, runtimeShell, fteqw-sv }:

let
  fteqw-sv' = fteqw-sv.overrideAttrs (oa: {
    pname = "${oa.pname}-asan";
    NIX_CFLAGS_COMPILE = "${oa.NIX_CFLAGS_COMPILE or ""} -fsanitize=address";
  });
in
stdenv.mkDerivation {
  pname = "${fteqw-sv'.pname}-bubblewrap";
  inherit (fteqw-sv') version;

  phases = [ "installPhase" "fixupPhase" ];

  buildInputs = [
    coreutils
    fteqw-sv
    bubblewrap
    rlwrap
  ];

  installPhase = ''
    install -D -m 755 $wrapperPath $out/bin/fteqw-sv
    ln -s ${fteqw-sv'}/bin/fteqw-sv $out/bin/fteqw-sv.real
  '';

  passAsFile = [ "wrapper" ];
  wrapper = ''
    #!${runtimeShell}
    set -euo pipefail

    : "''${TERM:=xterm-256color}"
    : "''${FTE_DATA_DIR:=$(${coreutils}/bin/realpath -- ./)}"

    exec -- env -i TERM="''${TERM}" HOME=/data \
            ${bubblewrap}/bin/bwrap --unshare-all \
            --share-net \
            --tmpfs / \
            --bind "''${FTE_DATA_DIR}" /data \
            --ro-bind /nix /nix \
            --ro-bind /etc /etc \
            --uid 1 --gid 1 \
            --hostname "quake" \
            --dir /dev --dev /dev \
            --dir /proc --proc /proc \
            --dir /tmp --tmpfs /tmp \
            -- ${rlwrap}/bin/rlwrap ${fteqw-sv'}/bin/fteqw-sv -nohome -basedir /data "''${@}"
  '';

  meta = with lib; {
    platforms = platforms.linux;
  };
}
