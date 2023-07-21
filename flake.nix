{
  inputs = {
    nixpkgs.url = github:NixOs/nixpkgs/nixos-23.05;
    zig.url = github:mitchellh/zig-overlay;
  };

  outputs = { self, zig, nixpkgs }:
    let
      name = "tul";

      # environment
      system = "x86_64-linux";

      # project reqs
      pkgs = (import nixpkgs) {
        inherit system;
      };
      zigpkgs = zig.packages.${system};

      inherit (pkgs.stdenv) mkDerivation;
      inputs = [ zigpkgs.master ];

      # create a derivation for the build with some args for `zig build`
      makePackage = buildArgs:
        let
          args =
            with pkgs.lib.strings;
            concatStrings (intersperse " " buildArgs);
        in
        mkDerivation {
          name = name;
          src = self;

          nativeBuildInputs = inputs;
          buildPhase = ''
            export HOME=$NIX_BUILD_TOP
            zig build ${args}
          '';

          installPhase = ''
            mkdir -p $out/bin/
            mkdir -p $bin/
            install zig-out/bin/${name} $bin/
            install zig-out/bin/${name} $out/bin/
          '';

          # TODO learn more about outputs and what is expected. I think using
          # bin by default makes sense for this project, but I would like to
          # understand more
          outputs = [ "bin" "out" ];
        };

      packages = {
        default = makePackage [ ];
        release = makePackage [ "-Doptimize=ReleaseFast" ];
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
      formatter.${system} = pkgs.nixpkgs-fmt;
      apps.${system} = apps;
      devShells.${system}.default = packages.default;
      packages.${system} = packages;
    };
}
