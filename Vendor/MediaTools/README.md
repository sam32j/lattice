# Media Optimizer image tools

Lattice builds these small helpers from the unmodified source archives in `Sources/`. No Homebrew runtime or Clop installation is required. Video uses macOS AVFoundation; JPEG/HEIC uses ImageIO.

| Component | Version | Source | SHA-256 |
| --- | --- | --- | --- |
| pngquant, including libimagequant | 2.17.0 | https://pngquant.org/pngquant-2.17.0-src.tar.gz | a27cf0e64db499ccb3ddae9b36036e881f78293e46ec27a9e7a86a3802fcda66 |
| libpng | 1.6.59 | https://downloads.sourceforge.net/project/libpng/libpng16/1.6.59/libpng-1.6.59.tar.xz | d80dd2a38a37f803cb9b6ac7b14bd6e74ddc3b654780a8380bdf93523fdb4389 |
| gifsicle | 1.98 | https://www.lcdf.org/gifsicle/gifsicle-1.98.tar.gz | e9d4cc0816db95c64d32e79f778836db0f1f7eb15868490bd330104e5146b66e |

pngquant/libimagequant use GPL-3.0-or-later (with additional notices in their COPYRIGHT files). gifsicle is a separate GPL-2.0 executable. libpng uses the libpng license. Complete source archives, notices and this build recipe accompany the distributed app under Resources/MediaTools. Run `./build.sh` to reproduce the helpers with Apple's command-line tools. No application code is linked to gifsicle.

pngquant 2.17 is the final self-contained C release and avoids a Rust toolchain dependency. It statically links this pinned libpng and system zlib. ImageIO converts PNG pixels to sRGB before quantization, so no separate color-management library is required. Tools process only explicitly selected local files in owned staging directories. Keep these pins reviewed when updating encoders.

To rebuild outside a checkout, copy the entire Resources/MediaTools directory from the app into a writable folder and run `sh build-media-tools.sh` there. It verifies the archives and writes the helpers to `build/media-tools` without installing anything.
