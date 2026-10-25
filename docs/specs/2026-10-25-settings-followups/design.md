# Settings and capture follow-ups

Base: refactor/lattice-naming 08297edd (PR #16). Branch: fix/settings-followups. Publish a PR targeting the naming branch, never merge main.

Apply the user's explicit settings hierarchy/copy choices using existing containers, SettingsRow, AppBundleList sheets and SettingsValueSlider. The direct, low-risk changes follow the design-spec exceptions; they do not need an invented redesign. New Magic Mouse behavior was separately presented and approved: use native macOS swipe progress/threshold, complete on gesture end, ignore momentum, retain current visuals and natural scrolling; preserve the trackpad's true 3/4-inch threshold and 1/4-inch first haptic. No mouse gesture should vibrate an unrelated trackpad.

Dock click becomes a single four-way choice with Off always selected when no valid active action exists. Off clears activation and unloads Dock Click without a permission prompt. Other choices use the existing verified Accessibility flow; denied/cancelled activation returns to Off. Clicking an already selected active tile remains selected. Existing conflicting flags must present one deterministic choice.

Fix screenshot Escape focus restoration at its actual ownership boundary; do not introduce cursor hiding or activate unrelated windows. Investigate OCR readiness/cancellation/error handling before selecting its implementation. OCR improvements should queue/recover real work and preserve clipboard ownership; a louder failure message alone is insufficient. Do not read user screenshots, change real permissions/hardware, control playback, or simulate physical input.

Verify behavior with existing isolated preferences, fake permission/clipboard/events, native unshown controls, synthetic OCR image fixtures and generated production-method boundaries. Native Magic Mouse integration requires documentation/source-backed routing and synthetic phase/cancellation tests; real hardware verification remains a stated limit.
