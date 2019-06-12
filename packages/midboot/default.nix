{ lib, newScope, callPackage, buildPackages
, busybox, fetchgit
, mk_kpart, linux-ng
}:

rec {

  uboot = callPackage ./uboot.nix {};

  dtbs = with linux-ng; doDtbs rec {
    config = makeConfig {
      inherit source;
      target = "alldefconfig";
      allconfig = getDefconfig {
        inherit source;
      };
    };
    source = doSource {
      version = "5.2.0";
      extraVersion = "-rc1";
      src = fetchgit {
        url = "https://github.com/torvalds/linux";
        rev = "v5.2-rc1";
        sha256 = "1szykchc76dh6gdpdi0q2xgd3zahpiakq2b7plqgikdx22mgcjdb";
      };
    };
  };

  kpart = mk_kpart {
    inherit dtbs;
    kernel = "${uboot}/u-boot.bin";
    initrd = null;
    kernelParams = [
      "loglevel=4"
    ];
  };

}

# busyboxStatic = busybox.override {
#   enableStatic = true;
# };
