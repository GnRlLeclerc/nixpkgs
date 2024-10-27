{
  lib,
  stdenv,
  addDriverRunpath,
  cudaPackages,
  buildPythonPackage,
  fetchurl,
  python,
  pythonOlder,
  autoPatchelfHook,
  filelock,
  lit,
  zlib,
}:

buildPythonPackage rec {
  pname = "triton";
  version = "3.1.0";
  format = "wheel";

  src =
    let
      pyVerNoDot = lib.replaceStrings [ "." ] [ "" ] python.pythonVersion;
      unsupported = throw "Unsupported system";
      srcs = (import ./binary-hashes.nix version)."${stdenv.system}-${pyVerNoDot}" or unsupported;
    in
    fetchurl srcs;

  disabled = pythonOlder "3.8";

  pythonRemoveDeps = [
    "cmake"
    # torch and triton refer to each other so this hook is included to mitigate that.
    "torch"
  ];

  buildInputs = [ zlib ];

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  propagatedBuildInputs = [
    filelock
    lit
    zlib
  ];

  dontStrip = true;

  # If this breaks, consider replacing with "${cuda_nvcc}/bin/ptxas"
  postFixup = (
    # The upstream build.py script links CUDA libraries (using -l, -L) in the cc_cmd variable.
    # We include the driver link path and the CUDA stubs library path.
    # At the time of writing, the cc_cmd variable is declared at line 44. Line 48 is the last line of cc_cmd += ["some other libraries"].
    # This command basically inserts this python line after line 47
    ''
      sed -i '48i \    cc_cmd += ["-L${addDriverRunpath.driverLink}", "-L${cudaPackages.cuda_cudart}/lib/stubs/"]' $out/${python.sitePackages}/triton/runtime/build.py
    '');

  meta = with lib; {
    description = "Language and compiler for custom Deep Learning operations";
    homepage = "https://github.com/triton-lang/triton/";
    changelog = "https://github.com/triton-lang/triton/releases/tag/v${version}";
    # Includes NVIDIA's ptxas, but redistributions of the binary are not limited.
    # https://docs.nvidia.com/cuda/eula/index.html
    # triton's license is MIT.
    # triton-bin includes ptxas binary, therefore unfreeRedistributable is set.
    license = with licenses; [
      unfreeRedistributable
      mit
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ junjihashimoto ];
  };
}
