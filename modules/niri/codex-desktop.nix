# Keep niri's tested native backend while updating the desktop application.
{ inputs, system }:
let
  niriDesktop = inputs.computer-use.packages.${system}.codex-desktop;
  pluginDir = "opt/codex-desktop/resources/plugins/openai-bundled/plugins/unified-computer-use";
in
inputs.codex-desktop.packages.${system}.codex-desktop-computer-use-ui.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    install -m755 ${niriDesktop}/${pluginDir}/bin/codex-computer-use-linux \
      "$out/${pluginDir}/bin/codex-computer-use-linux"
    for script in native-client native-service native-backend-service native-protocol; do
      install -m644 "${niriDesktop}/${pluginDir}/scripts/$script.mjs" \
        "$out/${pluginDir}/scripts/$script.mjs"
    done

    # Newer CUA runtimes close over the unsupported native Sky proxy in
    # getState. Build browser state through their public APIs instead.
    substituteInPlace "$out/${pluginDir}/scripts/native-client.mjs" \
      --replace-fail 'const browserState = cua.getState?.bind(cua);' \
      'const listBrowsers = cua.listBrowsers?.bind(cua);
  const listTabs = cua.listTabs?.bind(cua);
  const browserState = async () => ({ browsers: !listBrowsers ? [] : await Promise.all(
    (await listBrowsers({ emit: false })).map(async browser => ({
      ...browser, tabs: await listTabs({ browser: browser.id, emit: false }),
    })),
  ) });'
  '';
  passthru = (old.passthru or { }) // { niriBackend = niriDesktop.niriBackend; };
})
