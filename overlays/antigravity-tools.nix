final: prev:

let
  antigravity-tools-unwrapped = prev.stdenv.mkDerivation {
    pname = "antigravity-tools";
    version = "3.3.7";

    src = prev.fetchurl {
      url = "https://github.com/lbjlaq/Antigravity-Manager/releases/download/v3.3.7/Antigravity.Tools-3.3.7-1.x86_64.rpm";
      hash = "sha256-dMkX0hpKpS8pIKUE34LflHOmWJgH2iI60lJTW+zH/pI=";
    };

    nativeBuildInputs = with prev; [ rpm cpio ];

    unpackPhase = ''
      rpm2cpio $src | cpio -idmv
    '';

    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/share/applications
      mkdir -p $out/share/icons/hicolor/{32x32,128x128,256x256@2}/apps

      cp usr/bin/antigravity_tools $out/bin/
      cp usr/share/applications/*.desktop $out/share/applications/

      cp usr/share/icons/hicolor/32x32/apps/*.png $out/share/icons/hicolor/32x32/apps/
      cp usr/share/icons/hicolor/128x128/apps/*.png $out/share/icons/hicolor/128x128/apps/
      cp usr/share/icons/hicolor/256x256@2/apps/*.png $out/share/icons/hicolor/256x256@2/apps/
    '';

    meta = with prev.lib; {
      description = "Antigravity Tools - Antigravity account manager";
      homepage = "https://github.com/lbjlaq/Antigravity-Manager";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  antigravity-tools = prev.buildFHSEnv {
    name = "antigravity-tools";
    version = "3.3.7";

    targetPkgs = pkgs: with pkgs; [
      gtk3
      webkitgtk_4_1
      libsoup_3
      openssl_3
      glib
      gdk-pixbuf
      cairo
      pango
      atk
      libgcc
      bzip2
      zlib
      curl
      libayatana-appindicator
    ];

    multiPkgs = pkgs: with pkgs; [
      udev
      alsa-lib
      libpulseaudio
    ];

    runScript = "${antigravity-tools-unwrapped}/bin/antigravity_tools";

    extraInstallCommands = ''
      mkdir -p $out/share
      ln -s ${antigravity-tools-unwrapped}/share/applications $out/share/applications
      ln -s ${antigravity-tools-unwrapped}/share/icons $out/share/icons
    '';
  };

  antigravity-tools-unwrapped = antigravity-tools-unwrapped;
}
