{
  lib,
  stdenv,
  fetchFromGitLab,
  bash,
  makeWrapper,
  copyDesktopItems,
  jemalloc,
  ffmpeg-headless,
  python3,
  pkg-config,
  glib,
  vips,
  pnpm_9,
  nodejs,
  pixman,
  pango,
  cairo,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "sharkey";
  version = "2025.4.3";

  src = fetchFromGitLab {
    owner = "TransFem-org";
    repo = "Sharkey";
    domain = "activitypub.software";
    rev = finalAttrs.version;
    hash = "sha256-B268bSR5VFyJ/TaWg3xxpnP4oRj07XUpikJZ2Tb9FEY=";
    fetchSubmodules = true;
  };

  pnpmDeps = pnpm_9.fetchDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-S8LxawbtguFOEZyYbS1FQWw/TcRm4Z6mG7dUhfXbf1c=";
  };

  nativeBuildInputs = [
    copyDesktopItems
    pnpm_9
    nodejs
    makeWrapper
    python3
    pkg-config
  ];

  buildInputs = [
    glib
    vips

    pixman
    pango
    cairo
  ];

  configurePhase = ''
    runHook preConfigure

    export HOME=$(mktemp -d)
    export STORE_PATH=$(mktemp -d)

    export npm_config_nodedir=${nodejs}

    cp -Tr "$pnpmDeps" "$STORE_PATH"
    chmod -R +w "$STORE_PATH"

    pnpm config set store-dir "$STORE_PATH"
    pnpm install --offline --frozen-lockfile --ignore-scripts

    (
      cd node_modules/.pnpm/node_modules/v-code-diff
      pnpm run postinstall
    )
    (
      cd node_modules/.pnpm/node_modules/re2
      pnpm run rebuild
    )
    (
      cd node_modules/.pnpm/node_modules/sharp
      pnpm run install
    )
    (
      cd node_modules/.pnpm/node_modules/canvas
      pnpm run install
    )

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    find . -type f -exec sed -i 's/"packageManager": "pnpm@9\.6\.0",//g' {} +
    pnpm build

    runHook postBuild
  '';

  installPhase = let
    libPath = lib.makeLibraryPath [
      jemalloc
      ffmpeg-headless
      stdenv.cc.cc.lib
    ];

    binPath = lib.makeBinPath [
      bash
      pnpm_9
      nodejs
    ];
  in ''
    runHook preInstall

    mkdir -p $out/Sharkey

    ln -s /var/lib/sharkey $out/Sharkey/files
    ln -s /run/sharkey $out/Sharkey/.config
    cp -r * $out/Sharkey

    # https://gist.github.com/MikaelFangel/2c36f7fd07ca50fac5a3255fa1992d1a

    makeWrapper ${lib.getExe pnpm_9} $out/bin/sharkey \
      --chdir $out/Sharkey \
      --prefix PATH : ${binPath} \
      --prefix LD_LIBRARY_PATH : ${libPath}

    runHook postInstall
  '';

  passthru = {
    inherit (finalAttrs) pnpmDeps;
  };

  meta = with lib; {
    description = "🌎 A Sharkish microblogging platform 🚀";
    homepage = "https://joinsharkey.org";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [aprl sodiboo];
    platforms = ["x86_64-linux" "aarch64-linux"];
    mainProgram = "sharkey";
  };
})
