# JASSUB browser renderer

This directory contains JASSUB 2.5.20, bundled for the browser from the published npm package. Source: https://github.com/ThaUnknown/jassub

The upstream package declares this combined license expression: `LGPL-2.1-or-later AND (FTL OR GPL-2.0-or-later) AND MIT AND MIT-Modern-Variant AND ISC AND NTP AND Zlib AND BSL-1.0`. Its package `LICENSE` is included here. The bundle also incorporates `abslink` 1.3.1 (Apache-2.0), `lfa-ponyfill` 1.1.1 (MIT), `rvfc-polyfill` 1.0.8 (GPL-3.0), and `throughput` 1.0.2 (MIT), as declared by their package metadata. Their implementation is bundled into `jassub.js` and `worker.js`.

The two WASM files are the upstream normal and SIMD JASSUB builds. `default.woff2` is the upstream fallback font. Before distributing a packaged fnOS release, retain these notices and verify the applicable source-offer and font redistribution terms for the exact binaries being shipped.

For CJK glyphs, the Web integration reuses NipaPlay's existing `assets/subfont.ttf` (family name `Droid Sans Fallback`) instead of the Latin-only JASSUB default. This asset is already included by the app's Flutter asset bundle and is referenced by the bundled FVP documentation as its subtitle fallback. Its upstream font license still needs to be recorded with the final third-party asset notices before release.
