# Reference and fixture provenance

[中文](THIRD_PARTY_zh.md)

The MoonBit implementation and fixture source XML are authored for this repository
under [Apache-2.0](LICENSE). No third-party implementation source or sample APK is
included. The following external tools and specifications informed verification:

| Reference | Version or revision | Use |
| --- | --- | --- |
| [AOSP ResourceTypes.h](https://github.com/aosp-mirror/platform_frameworks_base/blob/d67e90e8a8301a87726420a1071fca8e52172bd4/libs/androidfw/include/androidfw/ResourceTypes.h) | d67e90e8a8301a87726420a1071fca8e52172bd4; Apache-2.0 | Binary layout and typed-value specification |
| [AOSP TypedValue.java](https://github.com/aosp-mirror/platform_frameworks_base/blob/d67e90e8a8301a87726420a1071fca8e52172bd4/core/java/android/util/TypedValue.java) | Same fixed AOSP revision; Apache-2.0 | Signed complex mantissas, radices, dimension and fraction unit definitions |
| Android SDK aapt2 | Build Tools 36.0.0, revision 2.20-13193326 | Compile authored XML and produce independent reference dumps |
| [Androguard](https://github.com/androguard/androguard) | 4.1.3; Apache-2.0 | Independently decode fixture XML and record semantic trees |
| [MoonBit core](https://github.com/moonbitlang/core) | 0.10.18+6c83a7f62; Apache-2.0 | Standard library and native host I/O; supplied by the toolchain |

Exact tool and input hashes, source paths, fixture origins, and reference-output
hashes are in [fixtures/manifest.json](fixtures/manifest.json). Android SDK tools
and Python dependencies are development-only and are not distributed here.
