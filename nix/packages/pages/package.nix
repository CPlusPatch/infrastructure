{pkgs ? import <nixpkgs> {}}:
pkgs.stdenv.mkDerivation {
  pname = "cpluspatch-pages";
  version = "0.1.0";

  src = ../../../html;

  nativeBuildInputs = [
    pkgs.bun
  ];

  buildPhase = ''
    runHook preBuild

    # Define files to build
    files=(
      "503.html"
      "502.html"
      "challenge.html"
      "maintenance.html"
    )

    http_files=(
      "dist/503.html"
      "dist/502.html"
    )

    echo "Building HTML files..."

    for file in "''${files[@]}"; do
      if [[ ! -f $file ]]; then
        echo "Error: File $file does not exist."
        exit 1
      fi

      echo "Building $file..."

      bun build "$file" \
        --outdir=./dist \
        --minify \
        --target=browser \
        --public-path=https://static.cpluspatch.com/pages/ \
        --format=esm \
        --sourcemap=linked
    done

    echo "HTML files built successfully."

    echo "Creating .http files..."

    for file in "''${http_files[@]}"; do
      if [[ ! -f $file ]]; then
        echo "Error: File $file does not exist."
        exit 1
      fi

      echo "Creating .http file for $file..."

      # Create the .http file
      cp "$file" "''${file%.html}.http"

      # Add the header to the .http file
      if [[ $file == "dist/503.html" ]]; then
        echo "HTTP/1.1 503 Service Unavailable" > "''${file%.html}.http"
      elif [[ $file == "dist/502.html" ]]; then
        echo "HTTP/1.1 502 Bad Gateway" > "''${file%.html}.http"
      fi

      echo "Cache-Control: no-cache" >> "''${file%.html}.http"
      echo "Content-Type: text/html" >> "''${file%.html}.http"
      # Add newline
      echo "" >> "''${file%.html}.http"

      # Append the content of the HTML file to the .http file
      cat "$file" >> "''${file%.html}.http"
    done

    echo "HTTP files created successfully."

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r dist/* $out/

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Static HTML assets for CPlusPatch infra stuff";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
