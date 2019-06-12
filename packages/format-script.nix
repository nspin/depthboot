{ lib, writeScript, runtimeShell, utillinux, vboot_reference }:

{ swapSize ? null
}:

let
  diskUUID = "A8ABB0FA-2FD7-4FB8-ABB0-2EEB7CD66AFA";
  bootUUID = "534078AF-3BB4-EC43-B6C7-828FB9A788C6";
  swapUUID = "0340EA1D-C827-8048-B631-0C60D4478797";
  rootUUID = "0340EA1D-C827-8048-B631-0C60D4478796";

in writeScript "format" ''
  #!${runtimeShell}
  set -e

  dev="$1"
  if [ ! -e "$dev" ]; then
    echo "'$dev' does not exist"
    exit 1
  fi

  echo sfdisk...
  ${utillinux.bin}/bin/sfdisk $dev <<EOF
    label: gpt
    label-id: ${diskUUID}
    size=64m, type=FE3A2A5D-4F32-41A7-B725-ACCC3285A309, uuid=${bootUUID}, name=kernel
    ${lib.optionalString (swapSize != null) "size=${swapSize}, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, uuid=${swapUUID}, name=swap"}
    type=B921B045-1DF0-41C3-AF44-4C6F280D3FAE, uuid=${rootUUID}, name=MY_ROOT_PART
  EOF

  echo cgpt...
  ${vboot_reference}/bin/cgpt add -i 1 -S 1 -T 5 -P 10 $dev
''
