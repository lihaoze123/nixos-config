{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  name = "gcc14-stdcpp-precompiled";
  buildInputs = [ pkgs.gcc14 ]; # 引入 gcc14 编译器[web:9]

  # 仅执行自定义阶段，跳过默认的 unpack/patch/configure
  phases = [ "buildPhase" "installPhase" ];

  buildPhase = ''
    # 定位 bits/stdc++.h 源文件完整路径
    export HEADER=$(echo | g++ -xc++ -E -v - 2>&1 \
      | sed -n '/#include <...> search starts here:/,/End of search list./p' \
      | grep bits/stdc++.h) \
    || exit 1

    # 预编译生成 .gch 文件
    g++ -x c++-header "$HEADER" -o stdc++.h.gch  \
    || exit 1
  '';

  installPhase = ''
    mkdir -p $out/include/bits

    # 复制原始头文件和预编译文件
    cp "$HEADER" $out/include/bits/stdc++.h  
    cp stdc++.h.gch    $out/include/bits/  
  '';
}

