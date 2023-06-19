{
  inputs = {
    nixpkgs.url = github:NixOs/nixpkgs/nixos-23.05;
    zig.url     = github:mitchellh/zig-overlay;
  };

  outputs = { self, zig, nixpkgs }:
    let
      name = "tul";

      # environment
      system = "x86_64-linux";

      # project reqs
      inherit (pkgs) mkShell;
      inherit (pkgs.stdenv) mkDerivation;
      pkgs = nixpkgs.legacyPackages.${system};
      zigpkgs = zig.packages.${system};

      inputs = [ zigpkgs.master ];
      extraShellInputs = with pkgs; [ gdb wabt ];

      # developer shell
      shell = mkShell {
        packages = inputs ++ extraShellInputs;
      };

      # create a derivation for the build with some args for `zig build`
      makePackage = buildArgs:
        let
          argv =
            with pkgs.lib.strings;
            concatStrings (intersperse " " buildArgs);
        in
          mkDerivation {
            name = name;
            src = self;

            buildInputs = inputs;
            buildPhase = ''
              export HOME=$NIX_BUILD_TOP
              zig build ${argv}
            '';

            installPhase = ''
              mkdir -p $out/bin/
              install zig-out/bin/${name} $out/bin/
            '';
          };

      packages = {
        default = makePackage [];
      };

      # app config for 'nix run'
      tulApp = {
        type = "app";
        program = "${self.packages.${system}.default}/tul";
      };

      apps = {
        default = tulApp;
        tul = tulApp;
      };
    in
      {
        apps.${system} = apps;
        devShells.${system}.default = shell;
        packages.${system} = packages;
      };
}