final: prev:

let
  eudicFontConfig = final.writeText "eudic-fontconfig.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <dir>${final.wqy_zenhei}/share/fonts</dir>

      <!-- Eudic bundles Qt WebEngine 5.15.2, which cannot render the
           variable Noto CJK font selected by the system font config. -->
      <alias binding="strong">
        <family>sans-serif</family>
        <prefer><family>WenQuanYi Zen Hei</family></prefer>
      </alias>
      <alias binding="strong">
        <family>Helvetica</family>
        <prefer><family>WenQuanYi Zen Hei</family></prefer>
      </alias>
      <alias binding="strong">
        <family>Arial</family>
        <prefer><family>WenQuanYi Zen Hei</family></prefer>
      </alias>
      <alias binding="strong">
        <family>Microsoft YaHei</family>
        <prefer><family>WenQuanYi Zen Hei</family></prefer>
      </alias>
      <alias binding="strong">
        <family>微软雅黑</family>
        <prefer><family>WenQuanYi Zen Hei</family></prefer>
      </alias>

      <match target="pattern">
        <test name="family" qual="any">
          <string>Noto Sans CJK SC</string>
        </test>
        <edit name="family" mode="prepend" binding="strong">
          <string>WenQuanYi Zen Hei</string>
        </edit>
      </match>
      <match target="pattern">
        <test name="family" qual="any">
          <string>Noto Serif CJK SC</string>
        </test>
        <edit name="family" mode="prepend" binding="strong">
          <string>WenQuanYi Zen Hei</string>
        </edit>
      </match>
    </fontconfig>
  '';
in
{
  eudic = prev.eudic.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];

    postFixup = (oldAttrs.postFixup or "") + ''
      wrapProgram "$out/bin/eudic" \
        --set FONTCONFIG_FILE ${eudicFontConfig} \
        --set QT_AUTO_SCREEN_SCALE_FACTOR 0 \
        --set QT_SCALE_FACTOR 2
    '';
  });
}
