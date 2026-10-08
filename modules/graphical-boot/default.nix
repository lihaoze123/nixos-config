{ config, lib, pkgs, ... }:
let
  # Fixed dark palette from the DMS "purple" theme; it does not follow
  # wallpaper-driven colours at runtime.
  background = "141218";
  accent = "#d0bcff";

  # Plymouth only upscales bitmaps, so it runs at DeviceScale=1 (see below) and
  # every asset is rendered here at the host's configured display scale.
  scale = config.my.graphicalBoot.scale;
  logoSize = 96 * scale;
  spinnerSize = 24 * scale;

  # Plymouth's spinner theme, recoloured with a centred NixOS logo.
  dmsPlymouthTheme = pkgs.runCommand "plymouth-dms-nixos"
    {
      nativeBuildInputs = [ pkgs.imagemagick ];
    } ''
    theme=$out/share/plymouth/themes/dms-nixos
    mkdir -p $theme
    spinner=${pkgs.plymouth}/share/plymouth/themes/spinner

    # Password prompt assets; only shown when something asks for input.
    for image in $spinner/*.png; do
      magick "$image" -filter Lanczos -resize ${toString (scale * 100)}% \
        -fill '${accent}' -colorize 100 "$theme/$(basename "$image")"
    done

    magick ${pkgs.nixos-icons}/share/icons/hicolor/1024x1024/apps/nix-snowflake-white.png \
      -filter Lanczos -resize ${toString logoSize}x${toString logoSize} \
      -fill '${accent}' -colorize 100 $theme/watermark.png

    # Draw the spinner at 4x and downsample for smooth edges at native size.
    big=$((${toString spinnerSize} * 4))
    stroke=$((big / 8))
    inset=$((stroke / 2 + 2))
    frame() {
      magick -size ''${big}x''${big} xc:none -fill none -stroke '${accent}' \
        -strokewidth $stroke -draw "stroke-linecap round arc $inset,$inset $((big - inset)),$((big - inset)) $1,$(($1 + 270))" \
        -resize ${toString spinnerSize}x${toString spinnerSize} "$2"
    }
    for i in $(seq 1 30); do
      frame $(((i - 1) * 12)) $theme/throbber-$(printf %04d $i).png
    done
    for i in $(seq 1 36); do
      frame $(((i - 1) * 10)) $theme/animation-$(printf %04d $i).png
    done

    sed $spinner/spinner.plymouth \
      -e '/^Name\[/d' \
      -e 's|^Name=.*|Name=DMS NixOS|' \
      -e 's|^Description=.*|Description=Spinner theme with a centred NixOS logo in DMS colours.|' \
      -e "s|^ImageDir=.*|ImageDir=$theme|" \
      -e 's|^Font=.*|Font=Cantarell ${toString (12 * scale)}|' \
      -e 's|^TitleFont=.*|TitleFont=Cantarell Light ${toString (30 * scale)}|' \
      -e 's|^VerticalAlignment=.*|VerticalAlignment=.62|' \
      -e 's|^WatermarkVerticalAlignment=.*|WatermarkVerticalAlignment=.5|' \
      -e 's|^BackgroundStartColor=.*|BackgroundStartColor=0x${background}|' \
      -e 's|^BackgroundEndColor=.*|BackgroundEndColor=0x${background}|' \
      > $theme/dms-nixos.plymouth
  '';

  plymouth = "${config.boot.plymouth.package}/bin/plymouth";

  # Wait (at most 15s) for the greeter's niri to create its Wayland socket,
  # plus a moment for its first frame.
  waitForGreeter = pkgs.writeShellScript "wait-for-greeter" ''
    uid=$(${pkgs.coreutils}/bin/id -u dms-greeter) || exit 0
    for _ in $(${pkgs.coreutils}/bin/seq 150); do
      for socket in /run/user/$uid/wayland-*; do
        if [ -S "$socket" ]; then
          exec ${pkgs.coreutils}/bin/sleep 1
        fi
      done
      ${pkgs.coreutils}/bin/sleep 0.1
    done
  '';
in
{
  options.my.graphicalBoot.scale = lib.mkOption {
    type = lib.types.ints.positive;
    default = 1;
    description = "Display scale used to render the Plymouth theme assets.";
  };

  config = lib.mkIf config.my.features.graphicalBoot.enable {
    boot.loader = {
      # Boot straight through; press Esc during the 1s window for the menu.
      timeout = 1;
      grub = {
        timeoutStyle = "hidden";
        # Keep the firmware mode so Plymouth starts without a mode switch.
        gfxpayloadEfi = "keep";
      };
    };

    boot.plymouth = {
      enable = true;
      theme = "dms-nixos";
      themePackages = [ dmsPlymouthTheme ];
      # Assets above are already at native resolution; stop Plymouth upscaling them.
      extraConfig = "DeviceScale=1";
    };

    # Hide routine boot text; Esc in Plymouth and journalctl -b still show it.
    boot.consoleLogLevel = 3;
    boot.initrd.verbose = false;
    boot.kernelParams = [
      "quiet"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "vt.global_cursor_default=0"
    ];

    my.niri.greeterExtraConfig = lib.mkBefore ''
      // Match the Plymouth background to avoid a flash between them.
      layout {
          background-color "#141218"
      }
    '';

    # Keep Plymouth's last frame until the greeter owns the display, avoiding
    # a return to the firmware framebuffer between the two compositors.
    services.greetd.greeterManagesPlymouth = true;
    systemd.services.greetd = {
      after = [ "plymouth-start.service" ];
      serviceConfig.Type = lib.mkForce "simple";
      preStart = lib.mkAfter ''
        if ${plymouth} --ping; then
          ${plymouth} deactivate || :
        fi
      '';
    };
    systemd.services.plymouth-quit = {
      after = [ "greetd.service" ];
      # A rebuild must not rerun the wait inside a running session.
      restartIfChanged = false;
      serviceConfig = {
        ExecStartPre = "-${waitForGreeter}";
        ExecStart = [ "" "-${plymouth} quit --retain-splash" ];
      };
    };
  };
}
