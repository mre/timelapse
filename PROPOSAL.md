# Timelapse for macOS 15+

The movie should be encoded while you work, not after you stop. Keep the original app’s menu-bar simplicity, replace its screenshot spool with an in-process video writer, and make recording state and failures visible.

## What the original tells us

Research checked the archived repository, implementation, and issue discussions on October 18, 2026. The legacy repository is now archived at [mre/timelapse-python](https://github.com/mre/timelapse-python). This implementation is a fresh Swift app, not a port of its Python packaging.

| Evidence | Consequence for this version |
| --- | --- |
| [`recorder.py`](https://github.com/mre/timelapse-python/blob/master/timelapse/recorder.py) spawns `screencapture`, writes numbered PNGs, and follows the pointer across displays. Its constructor defaults to a four-second interval. | Use ScreenCaptureKit directly. Capture a deliberately selected display at a configurable interval. |
| [`encoder.py`](https://github.com/mre/timelapse-python/blob/master/timelapse/encoder.py) runs external `ffmpeg` over `%d.png`, encoding H.264 at 30 fps after capture. | Encode each frame immediately with AVFoundation; no subprocesses, PNG spool, or runtime dependencies. |
| [#51: PNG storage growth](https://github.com/mre/timelapse-python/issues/51), [#46: faster video creation](https://github.com/mre/timelapse-python/issues/46) | Bound work to one outstanding capture and append. Stopping drains that work and finalizes the container, rather than encoding the session again. |
| [#47: errors after stopping](https://github.com/mre/timelapse-python/issues/47), [#50: no apparent output](https://github.com/mre/timelapse-python/issues/50) | Remove the external encoder dependency; show actionable errors and a Finder action for completed movies. |
| [#58: pause/resume](https://github.com/mre/timelapse-python/issues/58), [#42: configurable interval](https://github.com/mre/timelapse-python/issues/42) | Include both in the first version. |
| [#57: Ventura launch failure](https://github.com/mre/timelapse-python/issues/57) | Native Swift app bundle, macOS 15 minimum, no embedded Python. |
| [#49: region capture](https://github.com/mre/timelapse-python/issues/49), [#54: multiple displays](https://github.com/mre/timelapse-python/issues/54) | Make the source explicit. Defer region/window capture and simultaneous displays rather than silently switching sources. |
| [#32: screen lock](https://github.com/mre/timelapse-python/issues/32), [#55: suspend](https://github.com/mre/timelapse-python/issues/55) | Pause on sleep, screen sleep, and lock notification; require manual resume. Do not promise capture during sleep. |

Closed issues are not necessarily fixed requirements: #51 was closed without replacing the PNG-spooling design. The historical article describes earlier versions; the source above is the basis for implementation comparisons.

## First version

A menu-bar panel offers a display selector, capture interval, maximum image dimension, pointer toggle, and destination folder. Start, Pause, Resume, and Stop & Save are the only recording controls. Settings persist between launches. The menu-bar icon changes while recording or paused. The panel shows captured frame count and resulting movie duration.

Defaults: one frame every five seconds, 1920-pixel longest edge, H.264 in MP4, 30 fps playback, saved in `~/Movies/Timelapse`. One hour becomes approximately 24 seconds. The first frame is immediate; actual frame count depends on capture and encoding throughput. No audio, uploads, analytics, live thumbnail, or continuous preview.

The fixed-display default intentionally differs from the original pointer-following behavior. It prevents an innocent pointer movement from switching the movie to a private display. All visible content on the chosen display can still be recorded; users should hide sensitive windows and notifications. The app excludes its own windows.

## Capture and encoding design

1. Fetch shareable content after an explicit permission-related action. Resolve the chosen display again when recording starts.
2. Build a ScreenCaptureKit filter that excludes this process. Derive physical image size from the filter’s rectangle and pixel scale; preserve aspect ratio, cap the longest edge, and round down to even dimensions for H.264.
3. Request one sample buffer with `SCScreenshotManager`, including static desktop content. A low-rate `SCStream` needs additional logic to repeat unchanged frames; sparse screenshot requests keep the first implementation smaller and avoid maintaining a continuous stream.
4. Await an append on a separate writer actor. AVAssetWriter compresses directly from the pixel buffer. No image-file serialization or readback pass is required.
5. Set presentation time to `frameIndex / 30`, not wall time. Pause and sleep do not create long frozen stretches in the movie.
6. Sleep until the next capture deadline. If capture or encoding takes longer than the interval, do not queue catch-up work. Pause cancels the wait; an in-flight screenshot is discarded if its generation is no longer current.
7. On stop, wait for the single outstanding capture/append, end the video session at `frameCount / 30`, and finish the writer. Rename the `.partial.mp4` only after successful finalization. Preserve a completed movie if that rename fails.

AVFoundation selects the H.264 implementation; this version does not require or independently verify hardware acceleration. There is no full-session encoding pass on stop, but encoder flush, file-system work, and an outstanding screenshot still take time. ScreenCaptureKit does not expose cancellation for an outstanding screenshot request.

## Resource and reliability boundaries

The application never accumulates a queue of screenshots. One 1920 × 1080 BGRA frame is about 8 MiB; that is not the app’s total memory use, because the capture framework and encoder have their own buffers. Screenshot requests, pixel conversion, and compression still consume resources. Measure those costs before claiming a CPU percentage or battery-life improvement over a stream-based implementation.

Normal quit finishes the current movie. Capture errors stop recording and attempt to finalize already encoded frames. Zero-frame sessions are removed. Writer failures are reported. Sleep/lock notifications pause recording, but notification delivery and already captured frames are not a security boundary. The screen-lock notification is a system convention rather than a documented ScreenCaptureKit lifecycle contract and needs OS-version testing.

An interrupted, unfinalized MP4 may not be playable. Force-quit and power-loss recovery are **not implemented**; a leftover `.partial.mp4` is not advertised as a backup. The original maintainer raised recovery as a reason to retain screenshots in #51. A later version should evaluate independently playable short segments or fragmented MP4, including their compatibility and finalization costs. It should not reintroduce an unbounded PNG spool.

The app does not prevent sleep, cap movie size, auto-delete old movies, or guarantee a minimum amount of free disk space. Output still grows during long recordings, just as compressed video rather than PNGs. A full disk can prevent successful finalization.

## Validation and release gate

Automated checks cover configuration validation, aspect ratio and even dimensions, frame timestamps, empty cleanup, encoded frame counts, duration of short synthetic movies, and preserving a completed file on rename failure. They do not request Screen Recording permission or record the developer’s desktop.

Before a public release, manually test:

- Fresh permission grant, denial, revocation, and relaunch under a stable app identity.
- Static desktop and moving content on Retina, external, portrait, and mixed-scale displays.
- Pause/resume, immediate stop, immediate quit, stop during capture, and repeated sessions.
- Screen lock, display sleep, system sleep, wake, and display removal.
- Unwritable destinations, removable-drive removal, and disk-full errors.
- QuickTime playback, long recordings, screen text readability, and no unexpected black frames.
- Menu-bar panel layout in light/dark appearance, VoiceOver, and keyboard navigation.
- CPU, memory, energy use, file size, and stop latency over an hour at each interval/resolution. Compare sparse screenshots with a throttled stream before choosing a more complex capture backend.

Builds are locally ad-hoc signed by default. Public distribution needs a Developer ID, hardened-runtime signing, notarization, and stapling. The build script accepts a signing identity and can produce a universal binary. The first version is not sandboxed; an App Store version would need sandbox entitlements and persistent security-scoped access to user-selected destinations.
