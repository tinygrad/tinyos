{
  buildPythonPackage,
  numba,
  numpy,
  pyserial,
  pillow,
  setuptools,
  wheel,
}:
buildPythonPackage {
  pname = "tinyturing";
  version = "0.1.0";
  pyproject = true;
  src = ./.;

  nativeBuildInputs = [
    setuptools
    wheel
  ];

  propagatedBuildInputs = [
    numba
    numpy
    pyserial
    pillow
  ];

  pythonImportsCheck = [ "tinyturing" ];
}
