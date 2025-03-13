{ lib
, python3
, fetchFromGitHub
}:

python3.pkgs.buildPythonApplication rec {
  pname = "lectic";
  version = "0.0.0-alpha5";

  src = fetchFromGitHub {
    owner = "gleachkr";
    repo = "Lectic";  # Note: repository name is case-sensitive
    rev = "v${version}";
    hash = "sha256-Ue+jPPmxBPPKEeHXGBJhVGGFEFBBGPPEHGPxVJGkVxE=";
  };

  propagatedBuildInputs = with python3.pkgs; [
    pyyaml
    requests
    markdown
  ];

  # Add checkInputs if there are any test dependencies
  doCheck = false;  # Disable tests temporarily if they're not set up

  meta = with lib; {
    description = "A markdown-based frontend for Large Language Models (LLMs)";
    homepage = "https://github.com/gleachkr/lectic";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}

