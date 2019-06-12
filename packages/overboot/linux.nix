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

  common = nixosCommonConfig { inherit (source) version; };

  base = makeConfig {
    inherit source;
    target = "alldefconfig";
    allconfig = writeConfig (mergeConfig [
      defconfig
      common
    ]);
  };

  # base with only rockchip platform
  base-rockchip = ./config;
  # base with only rockchip platform and NET=n
  base-rockchip-nonet = ./nonet.config;
  # base with only rockchip platform and fewer drivers
  base-rockchip-less = ./less.config;
  # base with only rockchip platform and fewer drivers and even less
  base-rockchip-even-less = ./even-less.config;

  # config = base-rockchip-less;
  # config = base-rockchip-nonet;
  # config = base-rockchip-even-less;
  config = base-rockchip;

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

  env = configEnv {
    inherit source config;
  };

in doKernel rec {
  inherit source config;
  dtbs = true;
  nukeRefs = false;
  passthru = {
    inherit env;
    inherit common;
    # inherit base;
  };
}
