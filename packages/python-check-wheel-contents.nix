# check-wheel-contents - wheel content linter used during PyPI release rehearsals.
# Custom because nixpkgs packages none of it (absent from both stable and unstable);
# all of its runtime dependencies except one are in nixpkgs, so this is a plain
# sdist build plus a privately-pinned wheel-filename (see below).
{
  lib,
  buildPythonPackage,
  fetchPypi,
  hatchling,
  attrs,
  click,
  packaging,
  pydantic,
  pytestCheckHook,
  pytest-cov,
  pytest-mock,
}:

let
  # nixpkgs ships wheel-filename 2.x, but 2.0 replaced the parse_wheel_filename
  # function and InvalidFilenameError with WheelFilename.parse and ParseError.
  # check-wheel-contents 0.6.3 still imports the 1.x names, so its `~= 1.1` pin is
  # real and must not be relaxed. Pinned privately here rather than overriding the
  # attribute set-wide, so nothing else in the Python env is dragged back to 1.x.
  wheel-filename_1 = buildPythonPackage rec {
    pname = "wheel-filename";
    version = "1.4.2";
    pyproject = true;

    src = fetchPypi {
      pname = "wheel_filename";
      inherit version;
      hash = "sha256-h4kcRl3LtAtAOUqQbwGpMhS91Rql0l46mlnK5ivCmP0=";
    };

    build-system = [ hatchling ];

    # Same tox.ini --cov addopts situation as the parent package below.
    nativeCheckInputs = [
      pytestCheckHook
      pytest-cov
    ];

    pythonImportsCheck = [ "wheel_filename" ];

    meta = with lib; {
      description = "Parse wheel filenames";
      homepage = "https://github.com/wheelodex/wheel-filename";
      license = licenses.mit;
    };
  };
in
buildPythonPackage rec {
  pname = "check-wheel-contents";
  version = "0.6.3";
  pyproject = true;

  src = fetchPypi {
    pname = "check_wheel_contents";
    inherit version;
    hash = "sha256-EOaTni/k5s4e3y/27GFXgIZ36AeC54AhrhOd2IRzpEI=";
  };

  build-system = [ hatchling ];

  dependencies = [
    attrs
    click
    packaging
    pydantic
    wheel-filename_1
  ];

  # pytest-cov is not a test dependency upstream, but tox.ini's addopts pass --cov,
  # so pytestCheckHook needs the plugin present to parse its own arguments.
  nativeCheckInputs = [
    pytestCheckHook
    pytest-cov
    pytest-mock
  ];

  # These tests compare a walk of test/data/project-tree against an expected tree
  # containing foo.pyc and __pycache__ entries, but hatchling's default exclusions keep
  # bytecode out of the sdist, so the fixture is incomplete for any sdist-based build.
  # Deselected by exact node id rather than by -k, so test_from_local_tree_file and
  # test_from_local_tree_nonexistent (which pass) keep running. 952 tests still execute.
  disabledTestPaths = [
    "test/test_directory.py::test_from_local_tree"
    "test/test_directory.py::test_from_local_tree_no_include_root"
    "test/test_directory.py::test_from_local_tree_exclude_glob"
    "test/test_directory.py::test_from_local_tree_exclude_name"
    "test/test_directory.py::test_from_local_tree_exclude_multilevel_name"
    "test/test_directory.py::test_from_local_tree_directory_excluded"
    "test/test_directory.py::test_from_local_tree_file_excluded"
  ];

  pythonImportsCheck = [ "check_wheel_contents" ];

  meta = with lib; {
    description = "Check your wheels have the right contents";
    homepage = "https://github.com/jwodder/check-wheel-contents";
    license = licenses.mit;
    mainProgram = "check-wheel-contents";
  };
}
