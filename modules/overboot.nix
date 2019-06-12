{ config, lib, pkgs, ... }:

# /boot/overboot/1 -> ...
# /boot/overboot/2 -> ...
# ...
# /boot/overboot/n -> ...

with lib;

let
  cfg = config.boot.loader.overboot;

  overbootScript = pkgs.writeText "overboot.sh" ''
    #!${pkgs.runtimeShell}
    set -e
    kernel_params="$(cat @out@/kernel-params)"
    kernel_params="$kernel_params init=@out@/init"
    ${pkgs.kexectools}/bin/kexec -l -t Image --append="$kernel_params" --initrd=@out@/initrd @out@/kernel
    ${pkgs.kexectools}/bin/kexec -e
  '';

  overbootSetup = pkgs.writeScript "overboot-setup" ''
    #!${pkgs.runtimeShell}
    set -e
    dd if="${overbootKpart}" of="${cfg.partition}"
  '';

  overbootKpart = pkgs.depthboot.overboot.kpart;

in {

  options = {

    boot.loader.overboot.enable = mkEnableOption "overboot bootlader";

    boot.loader.overboot.partition = mkOption {
      example = "/dev/disk/by-partlabel/kernel";
      type = types.str;
    };

  };

  config = mkIf cfg.enable {

    system.boot.loader.id = "overboot";

    system.extraSystemBuilderCmds = ''
      substituteAll ${overbootScript} $out/overboot --subst-var out
      chmod +x $out/overboot
      ln -s ${overbootSetup} $out/overboot-setup
      ln -s ${overbootKpart} $out/overboot-kpart
    '';

    system.build.installBootLoader = pkgs.writeScript "install-overboot" ''
      #!${pkgs.runtimeShell}
      set -e
      set +o pipefail

      system=$1
      stat $system > /dev/null

      systems=/boot/overboot
      mkdir -pv $systems

      prev="$(ls $systems | sort -n | tail -n 1)"
      if [ -z "$prev" ]; then
        cur=0
      elif [ "$(readlink $systems/$prev)" = "$system" ]; then
        exit
      else
        cur="$(expr "$prev" + 1)"
      fi

      ln -sv $system "$systems/$cur"
    '';

  };

}
