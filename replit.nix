{ pkgs }: {
  deps = [
    pkgs.tesseract
    pkgs.tesseract_eng
    pkgs.ffmpeg
    pkgs.libglib
    pkgs.fontconfig
    pkgs.playwright-driver
    pkgs.chromium
    pkgs.stdenv.cc.cc.lib
  ];
}
