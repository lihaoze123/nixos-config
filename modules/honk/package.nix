{ lib, stdenvNoCC, fetchurl }:

# Matching honk/native-api + embedded doona build from the same release.
stdenvNoCC.mkDerivation {
  pname = "honk-core";
  version = "debug.2026.10.9.native-api.2";
  src = fetchurl {
    url = "https://github.com/Zakkaus/doona/releases/download/v0.1.0-beta.19/honk-core-debug-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "8b5c96b70f30f914b409e9e471c47faf347e19c048d6fa7964e4fec6ca293040";
  };
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 honk-core $out/bin/honk-core
    runHook postInstall
  '';
  meta = {
    description = "honk transparent proxy with native API and embedded doona beta.19";
    homepage = "https://github.com/Glassyiris/honk";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "honk-core";
  };
}
