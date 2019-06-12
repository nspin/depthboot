self: super: with self;

{

  scripts = callPackage ./scripts.nix {};

  mk-kpart = callPackage ./kpart.nix {};

}
