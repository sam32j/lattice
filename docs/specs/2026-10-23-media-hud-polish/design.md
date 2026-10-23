# Media Optimizer compact UI polish

Approved compact polish on 2026-10-23. Continue the existing isolated `feat/media-optimizer` worktree from clean commit 7d4bc437. No encoding, routing, file-save, shortcut or modifier-policy changes.

## Design

The shared window owns one rounded outer card. Embedded File Cache content keeps its existing header, tiles and actions but omits its nested backdrop/border. Standalone and docked File Cache retain their original chrome. A compact, visibly selected mode control is consistent between the shared window and island. The Option hint explains its purpose and appears only when both utilities share standalone presentation.

The optimizer keeps its compact preview and format bar. Copy and Reveal gain visible labels, drag-out stays available, and the original-preview control describes what it does. A Convert to heading clarifies that format buttons act immediately; a batch label states they apply to all files. File-count and status copy use natural singular/plural wording. Completed, busy, destination/error and batch states remain readable without hiding failures.

Use the same HUD content in light/dark standalone and island presentations. Preserve all actions, jobs, cache items, native drop receivers and dialog safeguards. Do not add dependencies or clipboard monitoring.

## Verification seams

Approved isolated rendering/model/window seams remain in use. Render actual SwiftUI views for empty, completed, busy, failed, destination and batch states in light/dark and island contexts. Check intrinsic sizes and manually inspect images. Existing media model tests cover job/result preservation and native shared-window probe checks modifier routing and same-panel identity. No real input events, permissions, user files or clipboard mutations. Run focused media/File Cache/island/settings tests, developer build, selftest, signature verification and independent source review. Commit by topic and push only the existing media branch; no PR or merge.
