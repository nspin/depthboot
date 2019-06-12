{ callPackage }:

rec {

  mk_kpart = callPackage ./kpart.nix {};

  mk_format_script = callPackage ./format-script.nix {};

  overboot = callPackage ./overboot {
    inherit mk_kpart;
  };

}
