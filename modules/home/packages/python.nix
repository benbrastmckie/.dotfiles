# Python packages and scientific computing stack
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    (python3.withPackages (p: (with p; [
      zulip # Zulip API client and zulip-send CLI
      z3-solver # Renamed from z3 in nixos-unstable
      setuptools
      pyinstrument
      build
      cvc5
      twine
      pytest
      pytest-cov
      pytest-timeout
      # model-checker  # don't install when in development
      tqdm
      pip
      pylatexenc
      pyyaml
      requests
      markdown
      jupyter
      jupyter-core
      notebook
      ipywidgets
      matplotlib
      networkx
      pynvim
      numpy
      pandas
      datasets
      huggingface-hub
      torch # PyTorch for machine learning and AI
      moviepy

      # Scientific computing stack (added for R/Quarto interop)
      scipy
      statsmodels
      seaborn
      pyarrow
      # pylint
      # black
      # isort

      # Jupyter Notebooks
      # jupytext               # DISABLED: 1.18.1 has 2 failing tests (async/sync ContentsManager mismatch). Re-enable once fixed upstream.
      ipython
      google-generativeai # Google Gemini API client (pip: google-genai)
      # pymupdf4llm          # LLM-optimized PDF extraction (custom package) - TEMPORARILY DISABLED: requires PyMuPDF 1.26.6, nixpkgs has 1.24.10
      # pdf2docx           # Convert PDF to DOCX - DISABLED: pulls python-docx 1.2.0 -> behave -> cucumber-expressions 18.1.0 -> uv_build<0.10.0 (nixpkgs has 0.10.0). Re-enable once fixed upstream.
      python-docx # Create/modify Word documents
      vosk # Offline speech recognition (custom package)
      pymupdf # PDF manipulation library
      # markitdown removed - depends on magika->onnxruntime; use: nix shell nixpkgs#python3Packages.markitdown
    ]) ++ [
      p.scikit-learn # Machine learning (hyphen requires dotted form outside with block)
    ]))
  ];
}
