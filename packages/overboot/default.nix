{ lib, newScope, callPackage, buildPackages
, busybox
, mk_kpart
}:

rec {

  linux = callPackage ./linux.nix {};

  initrd = callPackage ./initrd.nix {} {
    modules = linux.mod;
    moduleNames = [
      "panel_simple" "rockchipdrm" "pwm_bl" "pwm_cros_ec" "md_mod" "raid0" "raid1" "raid10" "raid456" "ext2" "ext4" "ahci" "sata_nv" "sata_via" "sata_sis" "sata_uli" "ata_piix" "pata_marvell" "sd_mod" "sr_mod" "mmc_block" "uhci_hcd" "ehci_hcd" "ehci_pci" "ohci_hcd" "ohci_pci" "xhci_hcd" "xhci_pci" "usbhid" "hid_generic" "hid_lenovo" "hid_apple" "hid_roccat" "hid_logitech_hidpp" "hid_logitech_dj"
      # "panel_simple"
      # "rockchipdrm"
      # "pwm_bl"
      # "pwm_cros_ec"
    ];
    dev = "/dev/disk/by-label/SD_FS_1";
  };

  kpart = mk_kpart {
    inherit (linux) kernel dtbs;
    inherit initrd;
    kernelParams = [
      "loglevel=4"
    ];
  };

}

# busyboxStatic = busybox.override {
#   enableStatic = true;
# };
