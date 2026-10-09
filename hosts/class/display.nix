{ config, lib, pkgs, ... }:
let
  edidPath = "edid/tongfang-a7000-60hz.bin";
  panelFirmware = pkgs.runCommand "class-panel-edid"
    { nativeBuildInputs = [ pkgs.python3 ]; }
    ''
      mkdir -p "$out/lib/firmware/edid"
      python3 - ${./panel-edid.hex} "$out/lib/firmware/${edidPath}" <<'PY'
      import sys
      from pathlib import Path

      # Captured from this A7000's eDP-1. Preserve its native 60 Hz timing,
      # identity and panel properties; remove only the 50.002 Hz timing.
      edid = bytearray.fromhex(Path(sys.argv[1]).read_text())
      assert len(edid) == 128 and edid[:8] == bytes.fromhex("00ffffffffffff00")
      assert sum(edid) % 256 == 0 and edid[126] == 0
      assert edid[54:72].hex() == "5136808c70382d40502035000f282100001a"
      assert edid[72:90].hex() == "442d808c70382d40502035000f282100000a"
      # EDID dummy descriptor (tag 0x10), not a new display mode.
      edid[72:90] = b"\x00\x00\x00\x10\x00" + bytes(13)
      edid[127] = (-sum(edid[:127])) & 0xff
      assert sum(edid) % 256 == 0
      Path(sys.argv[2]).write_bytes(edid)
      PY
    '';
in
{
  config = lib.mkIf config.my.features.desktop.enable {
    # Niri's fixed 60 Hz setting does not stop i915's idle DRRS downclock.
    # A single-timing EDID prevents DRRS without a debugfs polling service.
    hardware.firmware = [ panelFirmware ];
    boot.initrd.extraFirmwarePaths = [ edidPath ];
    boot.kernelParams = [ "drm.edid_firmware=eDP-1:${edidPath}" ];
  };
}
