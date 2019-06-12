{ lib, callPackage, writeText, runCommand, buildPackages
, dtc, ubootTools, lz4
}:

{ kernel, initrd, dtbs
, kernelParams
}:

let

  kernel-lz4 = runCommand "kernel.lz4" {
    nativeBuildInputs = [ lz4 ];
  } ''
    lz4 ${kernel} $out
  '';

  its = callPackage ./its.nix {
    inherit kernel-lz4 initrd dtbs;
  };

  itb = runCommand "itb" {
    nativeBuildInputs = [ ubootTools dtc ];
  } ''
    mkimage -D "-I dts -O dtb -p 2048" -f ${its} $out
  '';

  config = writeText "config" ''
    ${lib.concatStringsSep " " kernelParams}
  '';

  bootloader = runCommand "bootloader" {} ''
    dd if=/dev/zero of=$out bs=512 count=1
  '';

in runCommand "kpart" {
  nativeBuildInputs = [ buildPackages.vboot_reference ];
} ''
  futility vbutil_kernel \
    --pack $out \
    --version 1 \
    --vmlinuz ${itb} \
    --arch aarch64 \
    --keyblock ${buildPackages.vboot_reference}/share/vboot/devkeys/kernel.keyblock \
    --signprivate ${buildPackages.vboot_reference}/share/vboot/devkeys/kernel_data_key.vbprivk \
    --config ${config} \
    --bootloader ${bootloader}
''
