{ lib, runCommand, fetchgit, linux-ng }:

with linux-ng;

let
  source = doSource {
    version = "5.2.0";
    extraVersion = "-rc1";
    src = fetchgit {
      url = "https://github.com/torvalds/linux";
      rev = "v5.2-rc1";
      sha256 = "1szykchc76dh6gdpdi0q2xgd3zahpiakq2b7plqgikdx22mgcjdb";
    };
  };

  defconfig = readConfig (getDefconfig {
    inherit source;
  });

  allconfig = (mergeConfig [
    defconfig
    (commonConfig { inherit (source) version; })
  ]);

  config = makeConfig {
    inherit source;
    allconfig = writeConfig allconfig;
  };

in doKernel rec {
  inherit source config;
  dtbs = true;
}
