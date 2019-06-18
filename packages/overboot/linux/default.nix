{ lib, runCommand, fetchgit, linux-ng }:

with linux-ng;

let
  source = doSource rec {
    version = "5.2.0";
    extraVersion = "-rc4";
    src = fetchgit {
      url = "https://github.com/torvalds/linux";
      rev = "v5.2-rc4";
      sha256 = "0s495cmw2vrf1p7gfk7v7x6bpqr1y7fa3sh3j5kpszvzh7899lni";
    };
    patches = with kernelPatches; [
      <nixpkgs/pkgs/os-specific/linux/kernel/bridge-stp-helper.patch>
      <nixpkgs/pkgs/os-specific/linux/kernel/modinst-arg-list-too-long.patch>
    ];
  };

  # pkgs.linuxPackages_latest.kernel.configfile (nixos.config)

  # olddefconfig (synced.config)

  config = ./synced.config;

    # CONFIG_NET=n

    # config = ./nonet.config;

  # OR

    # CONFIG_...=n

    # config = ./lessnet.config;

  # END

  # # base with only rockchip platform
  # base-rockchip = ./config;
  # # base with only rockchip platform and NET=n
  # base-rockchip-nonet = ./nonet.config;
  # # base with only rockchip platform and fewer drivers
  # base-rockchip-less = ./less.config;
  # # base with only rockchip platform and fewer drivers and even less
  # base-rockchip-even-less = ./even-less.config;

  # # config = base-rockchip-less;
  # # config = base-rockchip-nonet;
  # # config = base-rockchip-even-less;
  # config = base-rockchip;

  # {
  #   DRM_ROCKCHIP = "y";
  #   DRM_ANALOGIX_DP = "y";
  #   ROCKCHIP_DW_HDMI = "y";
  #   DRM_DW_MIPI_DSI = "y";
  #   DRM_KMS_HELPER = "y";
  #   PWM_CROS_EC = "y";
  #   DRM_PANEL_SIMPLE = "y";
  #   BACKLIGHT_PWM = "y";
  #   DRM = "y";
  # }

in doKernel rec {
  inherit source config;
  dtbs = true;
  nukeRefs = false;
}
