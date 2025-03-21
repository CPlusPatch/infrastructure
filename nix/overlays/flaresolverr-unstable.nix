final: prev: let
  python = prev.pkgs.python3.withPackages (
    ps:
      with ps; [
        bottle
        func-timeout
        prometheus-client
        selenium
        waitress
        xvfbwrapper
        psutil
        packaging

        # For `undetected_chromedriver`
        looseversion
        requests
        websockets
        deprecated
        mss
      ]
  );
in {
  flaresolverr = prev.flaresolverr.overrideAttrs (old: {
    version = "3.3.21-fork";

    # Fix a bug with goofy ahh regex syntax parsed as an escape sequence
    postPatch = ''
      substituteInPlace src/utils.py \
        --replace-fail \
          'CHROME_EXE_PATH = None' \
          'CHROME_EXE_PATH = "${prev.lib.getExe prev.pkgs.chromium}"' \
        --replace-fail \
          'PATCHED_DRIVER_PATH = None' \
          'PATCHED_DRIVER_PATH = "${prev.lib.getExe prev.pkgs.undetected-chromedriver}"' \
        --replace-fail \
          'pattern = "\d+\.\d+\.\d+\.\d+"' \
          'pattern = "\\d+\\.\\d+\\.\\d+\\.\\d+"'
    '';

    installPhase = ''
      mkdir -p $out/{bin,share/${old.pname}-${old.version}}
      cp -r * $out/share/${old.pname}-${old.version}/.

      makeWrapper ${python}/bin/python $out/bin/flaresolverr \
        --add-flags "$out/share/${old.pname}-${old.version}/src/flaresolverr.py" \
        --prefix PATH : "${prev.lib.makeBinPath [prev.pkgs.xorg.xvfb prev.pkgs.chromium]}"
    '';

    src = prev.fetchFromGitHub {
      owner = "21hsmw";
      repo = "FlareSolverr";
      rev = "008ff71315baa40761d9d6283a248e50c43db491";
      hash = "sha256-Xf8eXXUV38Yl9fG+ToP0uNqBl+M6JdiRn3rUMltQ3a0=";
    };

    meta =
      old.meta
      // {
        broken = false;
      };
  });
}
