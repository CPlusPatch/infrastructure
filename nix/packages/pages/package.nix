# Error pages for HAProxy and the bot challenge page, also served on static.cpluspatch.com/pages
{
  lib,
  stdenv,
  bun,
}:
stdenv.mkDerivation {
  pname = "cpluspatch-pages";
  version = "0.1.0";

  src = ../../../html;

  nativeBuildInputs = [bun];

  buildPhase = ''
    runHook preBuild

    # Pages served normally, which load their assets from static.cpluspatch.com
    for file in challenge.html maintenance.html; do
      bun build "$file" \
        --outdir=dist \
        --minify \
        --target=browser \
        --public-path=https://static.cpluspatch.com/pages/ \
        --format=esm \
        --sourcemap=linked
    done

    # HAProxy error files: a raw HTTP response with the stylesheet inlined, so they still
    # render when the backend serving static.cpluspatch.com is the one that's down
    for page in "502 Bad Gateway" "503 Service Unavailable"; do
      code=''${page%% *}
      {
        printf 'HTTP/1.1 %s\r\nCache-Control: no-cache\r\nContent-Type: text/html\r\n\r\n' "$page"
        awk '/rel="preload"/ { next }
          /rel="stylesheet"/ {
            print "<style>"; while ((getline line < "css/main.css") > 0) print line; print "</style>"; next
          }
          { print }' "$code.html"
      } > "dist/$code.http"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r dist $out
    runHook postInstall
  '';

  meta = {
    description = "Static HTML assets for CPlusPatch infra stuff";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
