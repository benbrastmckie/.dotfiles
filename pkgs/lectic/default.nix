{ lib
, stdenv
, nodejs_20
, fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "lectic";
  version = "0.0.0-alpha5";

  src = fetchFromGitHub {
    owner = "gleachkr";
    repo = "Lectic";  # Note: repository name is case-sensitive
    rev = "v${version}";
    hash = "sha256-ZUMGteFXgMoDpsaTjUAGN1++CvefB1PpiWwUg7e86j8=";
  };

  nativeBuildInputs = [
    nodejs_20
  ];

  buildPhase = ''
    # Install dependencies
    npm ci
    # Build the project
    npm run build
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp -r dist/* $out/bin/
    chmod +x $out/bin/lectic
  '';

  meta = with lib; {
    description = "A markdown-based frontend for Large Language Models (LLMs)";
    homepage = "https://github.com/gleachkr/lectic";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}

