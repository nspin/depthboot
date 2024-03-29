{ config, lib, pkgs, ... }:

with lib;

# /boot/underboot/init -> systems/n
# /boot/underboot/systems/1 -> ...
# /boot/underboot/systems/2 -> ...
# ...
# /boot/underboot/systems/n -> ...

let
  cfg = config.boot.loader.underboot;

  kpart = pkgs.depthboot.mk_kpart {
    kernel = config.system.boot.loader.kernelPath;
    initrd = config.system.boot.loader.initrdPath;
    dtbs = config.hardware.deviceTree.package;
    kernelParams = config.boot.kernelParams ++ [ "init=/boot/underboot/init" ];
  };

in {

  options = {

    boot.loader.underboot.enable = mkEnableOption "underboot bootlader";

    boot.loader.underboot.partition = mkOption {
      example = "/dev/disk/by-partlabel/kernel";
      type = types.str;
      description = ''
        The kernel partition that holds the boot configuration. The
        value "nodev" indiciates the kpart partition should be
        created but not installed.
      '';
    };

    # TODO
    boot.loader.underboot.dtb = mkOption {
      type = types.string;
    };

  };

  config = mkIf cfg.enable {

    system.boot.loader.id = "underboot";

    system.extraSystemBuilderCmds = ''
      ln -s ${config.system.build.kpart} $out/underboot-kpart
    '';

    system.build = {

      inherit kpart;

      installBootLoader = pkgs.writeScript "install-underboot" ''
        #!${pkgs.runtimeShell}
        set -e
        set +o pipefail

        system=$1
        stat $system > /dev/null

        init=/boot/underboot/init
        systems=/boot/underboot/systems
        mkdir -pv $systems

        prev="$(ls $systems | sort -n | tail -n 1)"
        if [ -z "$prev" ]; then
          cur=0
        elif [ "$(readlink $systems/$prev)" = "$system" ]; then
          exit
        else
          cur="$(expr "$prev" + 1)"
        fi

        kpart="$(readlink $system/underboot-kpart)"
        stat $kpart > /dev/null

        if [ -n "$prev" ]; then
          kpart_prev="$(readlink $systems/$prev/underboot-kpart)"
          stat $kpart_prev > /dev/null
        else
          kpart_prev=
        fi

        ln -sv $system $systems/$cur
        ln -sfv systems/$cur/init $init

        ${lib.optionalString (cfg.partition != "nodev") ''
          if [ "$kpart" != "$kpart_prev" ]; then
            dd if="$kpart" of="${cfg.partition}"
          fi
        ''}
      '';

    };

  };

}
