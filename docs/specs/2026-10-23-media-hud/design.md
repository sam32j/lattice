# Shared File Cache and Media Optimizer HUD

Approved by the user, with the clarification that Option modifies a drag-and-shake invocation, not the keyboard shortcut. Continue on feat/media-optimizer from 8fca5ae2. Main and the downloader branch remain untouched.

## Interaction

When both utilities use standalone presentation, shaking a content drag opens File Cache. Holding Option temporarily switches the same NSPanel to Media Optimizer; releasing Option before a drop restores File Cache. Dropping into MO commits that mode so releasing Option cannot hide the running job. A visible mode picker is available without a modifier. File Cache contents and running optimization survive switching. Existing keyboard shortcuts remain unchanged.

MO has a compact preview/result HUD, native format bar and Copy, Reveal, drag-out and stronger-compression actions. Still images support JPEG, PNG and HEIC. GIF retains animation and only offers GIF. Videos offer H.264 and HEVC MP4. Unsupported or mixed drops are rejected explicitly, never silently stored or partially consumed. Quick optimization writes unique copies next to the sources, with a destination picker if a source folder is not writable. Explicit format conversion honors the selected format even when the result is larger; plain optimization retains original-quality copies when no size reduction is possible.

## Ownership

A small observable interaction state owns committed mode and transient drag preview. A separate HUD model owns input/result selection and delegates compression to MediaService. Platform presentation owns native panels and routing, never file processing. Reuse ShelfService's classic panel for standalone mode. Extract its existing panel construction into a focused extension before adding the shared host. Do not replace File Cache's storage or drag-out behavior. No clipboard watcher or automatic folder processing is added.

MO presentation may follow File Cache, use a standalone window, or use Dynamic Island when its Files widget is available. If the island cannot host it, use the standalone HUD rather than losing the operation. Rendering the same HUD in the existing Files surface retains existing module sizing and keep-open behavior. The existing advanced settings workspace remains available.

## Verification

Approved seams: modifier and routing policy, native conversion output, actual filesystem publication and original preservation, cancellation and mode switching, unsupported/mixed payloads, and isolated native/SwiftUI rendering in both presentations. Use temporary files and a test bundle, not real user hardware, settings, drag input or clipboard. Run affected and full suites, developer build, strict signature verification, selftest and independent source review. Commit by topic and push the existing media branch only. No PR work.
