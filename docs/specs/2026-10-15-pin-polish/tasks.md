# Pin control polish and pinch investigation

User confirmed controls appear in the rebuilt beta. Requested centered button symbols and glass styling; pinch still fails after clicking an unlocked pin with click-through disabled. Release publication remains paused until runtime verification.

- [x] Reproduce symbol displacement through native NSButtonCell geometry and a failing production-chrome test.
- [x] Replace older frosted circular surfaces with native Liquid Glass on macOS 26+, retaining the existing frosted appearance on older supported systems. Keep actions, placement, and hit targets unchanged.
- [x] Center symbol geometry explicitly. Existing native control/window test seam remains in use.
- [x] Confirm trackpad pinch preference is enabled. Inspect native gesture dispatch and calculation paths.
- [x] Reproduce tiny-packet zoom quantization in a failing production-view test (100 increments of 0.001 yielded width 300 instead of about 221).
- [x] Preserve logical zoom width across rounded native frames; reset after external geometry changes.
- [x] Correct the native content-view focus contract (acceptsFirstResponder and needsPanelToBecomeKey) and assign the first responder on image clicks. Red: native first-responder acquisition failed. Physical routing remains unverified.
- [x] Run focused regression checks including inward pinch, lock, click-through, opacity, file promises, and overlays (110 checks passed).
- [x] Obtain independent review: ready, no actionable findings. Native raster probing confirms the centering hook affects rendered symbols; visible bounds remain within 0.75 points of center.
- [x] Rebuild a private beta at `/Users/samuel/Developer/Codex/VS/artifacts/Vorssaint Beta Pin Polish.app`, source commit ccd765aa. Optimized build, strict deep signature verification, selftest, and ZIP integrity passed.
- [x] Ask user to verify physical pinch and revised glass controls before resuming release work. Awaiting reply; publication remains paused.

Artifact: `/Users/samuel/Developer/Codex/VS/artifacts/Vorssaint-Beta-pin-polish.zip`, SHA256 `bc6793af7c7dbc297c7cd9159905028ebd250dabcf8b0d049d4ec0b81973266c`.

## User runtime revision

User screenshot confirms glass circles clipped flat at the lower window edge. Requested removal of the press highlight because icons become illegible. Physical pinch result has not yet been supplied.

- [x] Add transparent drawing room around circular controls while keeping their screen positions unchanged. Plain content wrapper prevents native NSButton alignment insets from expanding the target.
- [x] Disable interactive glass press response and button-cell highlight/state decoration, preserving explicit lock/click-through tint. Native raster review confirmed identical normal/pressed icon pixels for all four symbols in active and inactive states.
- [ ] Verify focused tests, independent review, optimized build, selftest, signature, and archive.
- [ ] Obtain user runtime verification of the revised buttons and physical pinch. Publication remains paused.

Focused tests: 113 checks passed (`/private/tmp/pin-glass-final-tests.log`). Independent re-review: ready, no actionable findings. At 11:28 the running `/Applications/Vorssaint.app` executable exactly matched the ccd765aa private beta, confirmed by build stamp and SHA256; user already has the pinch-fixed executable running.

Evidence: /private/tmp/pin-polish-red.log (centering red), /private/tmp/pin-polish-glass-tests.log (78 pass), /private/tmp/pin-polish-pinch-red.log (tiny pinch red), /private/tmp/pin-polish-pinch-green.log (79 pass). Native routing probe using an NSEvent subclass was inconclusive and is not evidence of physical event delivery. Physical pinch remains unverified.
