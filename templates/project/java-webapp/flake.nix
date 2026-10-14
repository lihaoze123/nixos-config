{
  description = "Java 8 embedded Tomcat Servlet/JSP webapp";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      devShells = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          jdk = pkgs.temurin-bin-8;
        in
        {
          default = pkgs.mkShell {
            packages = [ jdk (pkgs.maven.override { jdk_headless = jdk; }) ];
            JAVA_HOME = "${jdk}";
          };
        });
    };
}
