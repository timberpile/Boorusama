# Local MP4 playback compatibility fallback

Research baseline: `develop` at `2e08f5d291dbe482cd1651183a486b93759f4927` (#180). Task branch: `bug/local-media-video-playback`. No new issue or PR was created.

## Evidence and diagnosis

- Owner reports some imported MP4s display no duration badge, report approximately two seconds in viewer despite longer playback, and freeze/drop video frames after the first loop while audio continues; eventually the video may turn black. Android logs show repeated codec pipeline saturation, zero rendered FPS and audio timestamp discontinuities of about 5.15 seconds. Working MP4s render normally with the same Qualcomm AVC decoder family.
- Owner confirmed on 2026-11-26 that affected videos play normally when switching to MPV. This confirms a usable alternative backend for the affected files, not which MP4 box is wrong. Exact MPV duration, seek and long-loop results, source file details and device matrix are still to be checked.
- [Media3 issue #3029](https://github.com/androidx/media/issues/3029): malformed MP4 track header durations substantially shorter than sample tables caused repeat playback freezes; a collaborator reproduced and resolved their sample by correcting track durations. Strong analogous evidence, not proof of the same file defect here. The issue was closed as bad media, not as a general upstream fix.
- Pinned `video_player_android` is khoadng/packages at `c32f6280eff5e9f0fe7c72a51fd74e7bb25d0bb5`, declaring Media3 1.9.2. Do not assume upgrading or globally ignoring edit lists fixes this case.

## Code paths

- `android/app/src/main/kotlin/com/timberpile/boorusama/LocalMediaInspection.kt`: `inspectVideo` validates codec/dimensions with Android MediaExtractor and records only first video track KEY_DURATION (nullable, currently zero accepted). MediaMetadataRetriever is already used for poster generation, not duration. Preserve bounds, MIME/decoder checks, cancellation and native resource release.
- `lib/core/local_media/local_media_providers.dart`: Android channel inspect returns LocalMediaProbe. `local_media_library.dart` persists duration_ms in SQLite on import. These import and storage paths are explicitly out of scope. `local_media_models.dart`: item.toPost/localMediaPost maps null to kNoduration and ms to seconds. `lib/core/posts/post/src/widgets/image_grid_item.dart`: unknown duration is intentionally an icon.
- `lib/core/posts/details/src/widgets/post_media.dart` _buildLocalMedia reads the configured video engine and passes a LocalFileVideoSource via sourceLoader; WebView selection is intentionally mapped to videoPlayerPlugin for local files.
- `lib/core/videos/player/src/types/video_player_state.dart` resolveVideoEngine: Android auto MP4 resolves to videoPlayerPlugin. `lib/core/videos/engines/src/providers/utils.dart` creates MediaKitBooruPlayer for MPV. Both engines consume the existing local source path/URI.
- `lib/core/videos/player/src/widgets/video_player.dart`: BooruVideo initializes the player, enables native looping, and forwards position and player.duration (not the stored duration) to viewer controls. `video_player_booru_player.dart` delegates to native VideoPlayerController.file; `media_kit_booru_player.dart` already supports single-item looping. Review duration/seek consumers in video_controls.dart and video_playback_manager.dart; do not just change UI duration or seek arithmetic.

## Approved scope (2026-11-26)

When a local Android MP4 is identified as incompatible with the default ExoPlayer backend, automatically play that file with the existing MPV backend. Do not change import metadata extraction, backfill stored durations, alter the database, or repair/remux media. A missing grid duration may remain unknown; the active viewer must show the actual selected player's duration. Do not make MPV the blanket default for all local videos. Keep ordinary compatible playback, remote playback and explicitly selected engines unchanged.

## Implementation direction

1. Reproduce the failing file privately on ExoPlayer and MPV, compare with known-good controls, and record the reported duration, timeline and repeat behavior. If useful, inspect ffprobe stream/packet timestamps and MP4 boxes (mvhd/tkhd/mdhd/stts/ctts/elst) on a local scratch copy. No requirement to repair the file or its metadata. Produce a synthetic regression fixture if practical. Do not upload private media.
2. Identify the smallest reliable file-specific detection signal on the playback path. The missing imported duration is a useful hint to investigate, not proof; a two-second duration can be legitimate. Prefer a cheap, read-only compatibility check before ExoPlayer playback if the reproduced defect has a deterministic signature. Compare declared duration with the actual presentation timeline only if a bounded, reliable probe is practical; handle timescales, edit lists and ordinary differing track lengths correctly. Do not run full decoding or a second player for every compatible video, add a general metadata subsystem, or scan the entire library. If preflight detection is not reliable, consider actual ExoPlayer playback failure signals, including the reproduced nonfatal timeline/render stall: the Dart controller's error state alone may miss it. Check whether the pinned plugin exposes sufficient native events; add only narrowly scoped native instrumentation if necessary. Do not parse logcat, classify all buffering as failure, or use a fixed short-duration threshold. Validate the chosen trigger against both failing and healthy fixtures before shipping. If no reliable trigger is found, report that blocker rather than silently switching all files to MPV.
3. Integrate with `PostMedia._buildLocalMedia`, source-aware engine selection, and/or `BooruVideo`'s player creation lifecycle, whichever fits the validated detector. For Auto on Android with an app-managed local MP4, start with the current default unless the compatibility check identifies this file; then use `VideoPlayerEngine.mpv` via the existing factory. If detection occurs during playback, transition to MPV for the same local source at most once per source generation. Await teardown of the old player and subscriptions; guard against stale events, navigation, disposal, duplicate fallbacks and wakelock races. Preserve pause/play intent, mute/volume, speed, poster/first-frame behavior, and valid position where possible. Do not seek to an untrustworthy ExoPlayer timestamp. Reapply loop settings and use the MPV duration and position for controls/seeking. If MPV also fails, surface the ordinary player error and do not retry indefinitely. Optional in-memory source-specific compatibility reuse is acceptable only if needed and safe; no new persistent format or global engine preference change. Preserve the existing local WebView mapping and other explicitly selected engines.
4. Preserve original bytes, SHA-256/MD5, IDs, references, tags, bookmarks and existing duration_ms; do not invoke import or modify persisted metadata from the player. No blanket Media3 flags, remux/transcode, dependency upgrades or unrelated playback changes.

## Acceptance and checks

- The affected video automatically uses MPV in Auto without changing the global preference; correct active viewer duration, seeking beyond two seconds, at least 20 loops without frozen/black frames, and safe navigation/close/reopen on a real Android device.
- Previously good MP4s, legitimate two-second MP4s and unknown-duration but compatible media are not misclassified; healthy Auto playback remains ExoPlayer. Remote media, WebM, explicit engine settings and non-Android behavior remain unchanged.
- Test deterministic detection, one-shot fallback, failure of MPV, cancellation/navigation during fallback, disposal, and preservation of playback settings. Verify no stale updates, duplicate active player, or leaks. Use existing test/videos and relevant local media/viewer tests; add a focused test for the actual failure mechanism (native/device fixture if needed).
- No import, stored duration, schema, file bytes, IDs, or reference changes. A missing thumbnail duration is explicitly not a regression target for this task.
- Run scope-appropriate tests and final fvm flutter analyze. Follow Android device coordination and keep private media out of Git. Full suite on final integration candidate before integration. Document the actual trigger, evidence, results and any limitations. No merge, PR, issue publication or release without explicit authorization.

## Implementation and reproduction

All five supplied examples contained two concatenated fragmented MP4 streams.
Each stream had its own top-level `ftyp` and `moov`, and both started at
fragment sequence 1 and decode time zero. The second initialization box matched
the first byte for byte in all five examples. The movie and track headers
declared zero duration. Each file instead contained multiple short segment
indexes. Media3 1.9.2 can publish the first `sidx` as the seek map, which
accounts for a viewer timeline of around two seconds. The repeated fragment
timeline is the compatibility signature from these files.

Playback preflight applies to app-managed Android MP4s in Auto. Its initial
scan reads box headers in a background isolate and skips media payloads. It
requires two separately initialized fragmented streams with media data, the
same first track ID, a restarted fragment sequence, and decode time zero at
both starts.
It gives up after 4,096 box headers and leaves the normal engine selection in
place if the structure is inconclusive. The resulting player is MPV from the
start, so the viewer uses MPV's duration and never inherits an ExoPlayer
position. Native playback and subscriptions are released when switching engines.
An MPV startup error reaches the viewer's normal error state.

To generate a playable control and a regression input with a restarted
timeline, run the following in a scratch directory.

```sh
ffmpeg -f lavfi -i 'testsrc2=size=192x108:rate=12:duration=5.2' \
  -f lavfi -i 'sine=frequency=480:duration=5.2' -c:v libx264 \
  -pix_fmt yuv420p -g 24 -c:a aac -movflags +dash+skip_trailer \
  -frag_duration 2000000 single-fragmented-stream.mp4
cat single-fragmented-stream.mp4 single-fragmented-stream.mp4 > restarted-timeline.mp4
```

## Verification

- The scoped Flutter run passed 468 tests across the player, Local Media,
  viewer, navigation, and Gelbooru consumer paths. It included one local-only
  classification test covering all five supplied samples. Final
  `fvm flutter analyze --no-pub` reported no issues. Original SHA-256 values
  matched before and after verification. Five additional playable fixture
  checks covered the restarted timeline, ordinary MP4, a legitimate
  two-second MP4, and single-initialization fragmented files with and
  without segment indexes.
- On the Android emulator, Auto selected MPV for the synthetic concatenated
  file. The viewer showed a five-second duration, accepted a seek to four
  seconds, and reopened the file after it was closed. With the final APK,
  the six-second and legitimate two-second controls opened and released
  ExoPlayer, as confirmed by native logs. The production MPV
  renderer hit `EGL_BAD_ATTRIBUTE` and the recorded video area stayed black
  even as the timeline advanced and restarted. Disabling Impeller at launch
  produced the same EGL error. Physical-device rendering and the 20-loop
  acceptance check require a device with working MPV output.
  [MediaKit Android emulator report](https://github.com/media-kit/media-kit/issues/1343)
- A diagnostic APK used MediaKit's `mediacodec_embed` output only for the
  emulator run. In a 165-second synthetic recording, frame matching at 12 fps
  counted 32 complete passes of the clip's content, equivalent to 16 passes
  through the two concatenated streams. No sampled video frame was black.
  The longest hold on one matched frame was 167 ms. The diagnostic build
  also rendered a supplied sample with a 36-second viewer duration and
  accepted a seek past 20 seconds. The candidate uses MediaKit's existing
  renderer.

## Repeat playback follow-up

The owner observed faster playback on the second pass with MPV. In all five
supplied files, the second `ftyp` began at the exact midpoint and the two
halves matched byte for byte. Packet inspection showed decode timestamps
returning to zero at the join. MPV timing on the generated fixture alternated
between roughly 5.3 and 3.3 seconds per pass when both streams were present.

For a detected restart at the midpoint, the probe compares both halves byte
for byte in 64 KiB chunks. It limits this extra read to files of at most
64 MiB. On an exact match, Android Auto passes the verified byte range of
the managed original to MPV using its seekable `slice://0-end@path` input.
MPV can then seek and loop within one complete stream. When the halves differ
or exceed the comparison budget, MPV plays the full original. Explicit
engine choices bypass this preflight.
[MPV byte-range inputs](https://mpv.io/manual/stable/#protocols)

The first implementation wrote the verified half to the app cache on each
open. Review confirmed that MediaKit's ordinary playlist accepts a local
MPV byte range directly. This removes the cache write and lets playback
work when storage is too full for a second file. Review also fixed a player
reuse bug where switching from a local fallback to a remote MP4 in Auto
could keep the previous MPV backend.

## Review verification

- On the synthetic 5.25-second fixture, host libmpv alternated between
  approximately 5.3 and 3.3 seconds per pass on the full file. Playing the
  verified range gave 22 complete intervals of 5.13–5.28 seconds.
- The Android library bundled with the app opened the range through a
  plaintext playlist on the x86_64 emulator. It reported exactly 108,997
  bytes from the 217,994-byte original, accepted a seek to four seconds and
  completed 20 intervals of 5.21–5.34 seconds using null video and audio
  output. These measurements cover native timeline cadence.
- The reviewed APK imported the synthetic clip through Local Media. The
  viewer displayed a five-second duration and accepted a seek to four
  seconds. Reopening it produced the expected 108,997-byte range in
  MediaKit's playlist, pointing directly to the managed original.
- The production renderer still reported `EGL_BAD_ATTRIBUTE` on this
  emulator. The earlier 18 rendered intervals used a diagnostic renderer
  and the temporary-copy implementation. Visible playback cadence with
  the production renderer on a physical Android device remains pending.
- The five private source files were unavailable at their recorded paths
  during this review. The byte comparison for those files is from the
  original investigation.
