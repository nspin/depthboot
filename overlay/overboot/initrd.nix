{ lib, stdenv, buildPackages
, runCommand, runCommandCC, writeText, writeTextFile, writeScript, writeShellScriptBin, substituteAll
, writeScriptBin

, busybox
, systemd, udev ? systemd
, rsync, cpio, gzip

, makeModulesClosure
}:

{ modules
, moduleNames
, dev
}:

with lib;

let

  modulesClosure = makeModulesClosure {
    rootModules = moduleNames;
    kernel = modules;
    firmware = modules;
    allowMissing = true;
  };

  findLibs = writeScript "find-libs" ''
    #!${stdenv.shell}
    set -euo pipefail

    declare -A seen
    declare -a left

    patchelf="${buildPackages.patchelf}/bin/patchelf"

    function add_needed {
      rpath="$($patchelf --print-rpath $1)"
      dir="$(dirname $1)"
      for lib in $($patchelf --print-needed $1); do
        left+=("$lib" "$rpath" "$dir")
      done
    }

    add_needed $1

    while [ ''${#left[@]} -ne 0 ]; do
      next=''${left[0]}
      rpath=''${left[1]}
      ORIGIN=''${left[2]}
      left=("''${left[@]:3}")
      if [ -z ''${seen[$next]+x} ]; then
        seen[$next]=1

        # Ignore the dynamic linker which for some reason appears as a DT_NEEDED of glibc but isn't in glibc's RPATH.
        case "$next" in
          ld*.so.?) continue;;
        esac

        IFS=: read -ra paths <<< $rpath
        res=
        for path in "''${paths[@]}"; do
          path=$(eval "echo $path")
          if [ -f "$path/$next" ]; then
            res="$path/$next"
            echo "$res"
            add_needed "$res"
            break
          fi
        done
        if [ -z "$res" ]; then
          echo "Couldn't satisfy dependency $next" >&2
          exit 1
        fi
      fi
    done
  '';

  extraUtils = runCommandCC "extra-utils" {
    nativeBuildInputs = [ buildPackages.nukeReferences ];
    allowedReferences = [ "out" ]; # prevent accidents like glibc being included in the initrd
  } ''
    set +o pipefail

    mkdir -p $out/bin $out/lib

    copy_bin_and_libs () {
      [ -f "$out/bin/$(basename $1)" ] && rm "$out/bin/$(basename $1)"
      cp -pdv $1 $out/bin
    }

    for BIN in ${busybox}/{s,}bin/*; do
      copy_bin_and_libs $BIN
    done

    copy_bin_and_libs ${udev}/lib/systemd/systemd-udevd
    copy_bin_and_libs ${udev}/bin/udevadm
    for BIN in ${udev}/lib/udev/*_id; do
      copy_bin_and_libs $BIN
    done

    # Copy ld manually since it isn't detected correctly
    cp -pv ${stdenv.cc.libc.out}/lib/ld*.so.? $out/lib

    # Copy all of the needed libraries
    find $out/bin $out/lib -type f | while read BIN; do
      echo "Copying libs for executable $BIN"
      for LIB in $(${findLibs} $BIN); do
        TGT="$out/lib/$(basename $LIB)"
        if [ ! -f "$TGT" ]; then
          SRC="$(readlink -e $LIB)"
          cp -pdv "$SRC" "$TGT"
        fi
      done
    done

    # Strip binaries further than normal.
    chmod -R u+w $out
    stripDirs "$STRIP" "lib bin" "-s"

    # Run patchelf to make the programs refer to the copied libraries.
    find $out/bin $out/lib -type f | while read i; do
      if ! test -L $i; then
        nuke-refs $i
      fi
    done

    find $out/bin -type f | while read i; do
      if ! test -L $i; then
        echo "patching $i..."
        patchelf --set-interpreter /lib/ld-linux-aarch64.so.1 --set-rpath /lib $i || true
      fi
    done
  '';

  udevRules = runCommand "udev-rules" {
    allowedReferences = [ extraUtils ];
    preferLocalBuild = true;
  } ''
    mkdir -p $out

    echo 'ENV{LD_LIBRARY_PATH}="${extraUtils}/lib"' > $out/00-env.rules

    cp -v ${udev}/lib/udev/rules.d/60-cdrom_id.rules $out/
    cp -v ${udev}/lib/udev/rules.d/60-persistent-storage.rules $out/
    cp -v ${udev}/lib/udev/rules.d/80-drivers.rules $out/
  '';

  bootStage1 = writeTextFile {
    name = "init";
    executable = true;
    checkPhase = ''
      ${buildPackages.bash}/bin/sh -n $out
      ${buildPackages.busybox}/bin/ash -n $out
    '';
    text =
      let
        # shell = "${extraUtils}/bin/ash";
        # inherit udevRules extraUtils modulesClosure;
        inherit modulesClosure;
      in ''
      #!/bin/sh

      console=/dev/tty1

      export LD_LIBRARY_PATH=/lib
      export PATH=/bin
      mkdir -p /usr
      mkdir -p /tmp
      mkdir -p /mnt
      mkdir -p /nix/store
      ln -s /sbin /bin
      ln -s /bin /usr/bin

      interact() {
        setsid /bin/sh -c "/bin/sh <$console >$console 2>$console"
      }

      fail() {
        echo "Failed. Starting interactive shell..." >$console
        interact
      }
      trap 'fail' 0

      specialMount() {
        mkdir -m 0755 -p "$2"
        mount -n -t "$4" -o "$3" "$1" "$2"
      }
      specialMount "devtmpfs" "/dev" "nosuid,strictatime,mode=755,size=5%" "devtmpfs"
      specialMount "proc" "/proc" "nosuid,noexec,nodev" "proc"
      specialMount "tmpfs" "/run" "nosuid,nodev,strictatime,mode=755,size=25%" "tmpfs"
      specialMount "sysfs" "/sys" "nosuid,noexec,nodev" "sysfs"

      echo /bin/modprobe > /proc/sys/kernel/modprobe

      echo "running udev..."
      mkdir -p /dev/.mdadm
      systemd-udevd --daemon
      udevadm trigger --action=add
      udevadm settle

      dev=${dev}
      mount "$dev" /mnt
      mount --bind /mnt/nix/store /nix/store

      cur="$(ls /mnt/boot/overboot | sort -n | tail -n 1)"
      "/mnt/boot/overboot/$cur/overboot" >$console 2>$console
      echo "Failed (reached end of /init). Starting interactive shell..." >$console
      interact
    '';
  };

in runCommand "initrd.gz" {
  nativeBuildInputs = [ rsync cpio gzip ];
  passthru = {
    inherit bootStage1 extraUtils udevRules;
  };
} ''
  mkdir root

  cp ${bootStage1} root/init
  rsync -a ${extraUtils}/ root/
  rsync -a ${modulesClosure}/ root/

  chmod +w root

  mkdir -p root/etc/udev/rules.d
  cp ${udevRules}/* root/etc/udev/rules.d

  cd root && find * -print0 | sort -z | cpio -o -H newc -R +0:+0 --reproducible --null | gzip > $out
''

# (isYes "TMPFS")
# (isYes "BLK_DEV_INITRD")
