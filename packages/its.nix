{ writeText, runCommand, lib
, kernel-lz4, initrd, dtbs
}:

let

  head = writeText "x" (''
    /dts-v1/;

    / {
        description = "Chrome OS kernel image with one or more FDT blobs";
        images {
            kernel@1 {
                description = "kernel";
                data = /incbin/("${kernel-lz4}");
                type = "kernel_noload";
                arch = "arm64";
                os = "linux";
                compression = "lz4";
                load = <0x00200000>;
                entry = <0x00200000>;
            };
  '' + lib.optionalString (initrd != null) ''
            ramdisk@1 {
                description = "ramdisk";
                data = /incbin/("${initrd}");
                type = "ramdisk";
                arch = "arm64";
                os = "linux";
                compression = "none";
                hash@1 {
                    algo = "sha1";
                };
            };
  '');

  mid = writeText "x" ''
        };
        configurations {
            default = "conf@0";
  '';

  tail = writeText "x" ''
        };
    };
  '';

in
runCommand "its" {} (''
  dtb_files=($(find -L ${dtbs} -type f -name '*.dtb'))

  fdt_definition() {
      local idx=$1
      local filename=$2
      local basename=$(basename $filename)
      cat <<EOF
          fdt@''${idx}{
              description = "''${basename}";
              data = /incbin/("''${filename}");
              type = "flat_dt";
              arch = "arm64";
              compression = "none";
              hash@1{
                  algo = "sha1";
              };
          };
  EOF
  }

  fdt_reference() {
      local idx=$1
      cat <<EOF
          conf@''${idx}{
              kernel = "kernel@1";
              fdt = "fdt@''${idx}";
'' + lib.optionalString (initrd != null) ''
              ramdisk = "ramdisk@1";
'' + ''
          };
  EOF
  }

  cat ${head} >> $out

  for index in "''${!dtb_files[@]}"; do
      fdt_definition $index ''${dtb_files[$index]} >> $out
  done

  cat ${mid} >> $out

  for index in "''${!dtb_files[@]}"; do
      fdt_reference $index >> $out
  done

  cat ${tail} >> $out
'')
