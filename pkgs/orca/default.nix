{
  appimageTools,
  fetchurl,
  gobject-introspection,
  lib,
  makeWrapper,
  python313,
  writeShellScriptBin,
  stdenv,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./version.json);

  assetMap = {
    "x86_64-linux" = "orca-linux.AppImage";
    "aarch64-linux" = "orca-linux-arm64.AppImage";
  };

  asset =
    assetMap.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  hash =
    versionData.hashes.${stdenv.hostPlatform.system}
      or (throw "No hash for system: ${stdenv.hostPlatform.system}");

  version = versionData.version;
  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/${asset}";
    inherit hash;
  };

  contents = appimageTools.extract {
    pname = "orca";
    inherit version src;
  };

  pythonWithAtspi = python313.withPackages (pythonPackages: [ pythonPackages.pygobject3 ]);

  # Keep this provider inside Orca's FHS root only. The sidecar requests
  # `python3`, but Orca's other Python environment may not include PyGObject.
  python3Provider = writeShellScriptBin "python3" ''
    export GI_TYPELIB_PATH="/usr/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
    export LD_LIBRARY_PATH="/usr/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec ${pythonWithAtspi}/bin/python3 "$@"
  '';
in
appimageTools.wrapType2 {
  pname = "orca";
  inherit version src;
  nativeBuildInputs = [ makeWrapper ];
  extraPkgs = pkgs: [
    gobject-introspection
    python3Provider
  ];

  extraInstallCommands = ''
    wrapProgram $out/bin/orca --add-flags --no-sandbox

    # Upstream has shipped both `Exec=AppRun --no-sandbox %U` and `Exec=AppRun %U`;
    # the wrapper already adds --no-sandbox, so point every Exec at it either way.
    install -Dm444 ${contents}/orca-ide.desktop $out/share/applications/orca.desktop
    sed -i -E 's|^Exec=AppRun( --no-sandbox)?|Exec=orca|' $out/share/applications/orca.desktop
    if grep -q AppRun $out/share/applications/orca.desktop \
      || ! grep -q '^Exec=orca' $out/share/applications/orca.desktop; then
      echo "orca.desktop: unexpected Exec line, update the rewrite above" >&2
      exit 1
    fi

    install -Dm444 ${contents}/usr/share/icons/hicolor/512x512/apps/orca-ide.png \
      $out/share/icons/hicolor/512x512/apps/orca-ide.png
  '';

  meta = {
    description = "Agentic development environment for working with parallel coding agents";
    homepage = "https://onorca.dev";
    downloadPage = "https://github.com/stablyai/orca/releases";
    license = lib.licenses.mit;
    platforms = builtins.attrNames assetMap;
    mainProgram = "orca";
  };
}
