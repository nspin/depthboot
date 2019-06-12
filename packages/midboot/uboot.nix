{ lib, runCommand, fetchgit, uboot-ng }:

with uboot-ng;

let
  source = doSource rec {
    version = "2019.04";
    src = fetchgit {
      url = "https://github.com/u-boot/u-boot";
      rev = "v${version}";
      sha256 = "1vc6dh9a0bjwgs8x5cl282gasn0hqcvjfsipgf7hyxq5jrhl3qyg";
    };
  };

  defconfig = getDefconfig {
    inherit source;
    defconfig = "chromebook_bob_defconfig";
  };

  chromebook_kevin_defconfig = runCommand "chromebook_kevin_defconfig" {} ''
    sed s/bob/kevin/ ${defconfig} > $out
  '';

  allconfig = defconfig;

  # allconfig = chromebook_kevin_defconfig;

  # allconfig = writeConfig (mergeConfig [
  #   (readConfig defconfig)
  #   {
  #     DEFAULT_FDT_FILE = "\"rockchip/rk3399-gru-kevin.dtb\"";
  #     DEFAULT_DEVICE_TREE= "\"rk3399-gru-kevin\"";
  #     OF_LIST = "\"rk3399-gru-kevin\"";
  #   }
  # ]);

  config = makeConfig {
    inherit source;
    target = "alldefconfig";
    allconfig = allconfig;
  };

in doKernel rec {
  inherit source config;
  filesToInstall = [
    "u-boot.bin"
  ];
  passthru = {
    inherit source config;
    inherit defconfig;
    # inherit x;
  };
}
