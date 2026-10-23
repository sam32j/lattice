# Unsolicited permission requests

Approved: fix both Cleaner-triggered Media Library access and accessory Bluetooth activation. Continue on the existing refactor/settings-refactor-III checkout, clean at 0e46b506.

## Evidence and behavior

The first Media Library prompt occurred at 09:00:00, matching the configured daily Cleaner schedule. The stored automatic-cleanup completion timestamp is 11:13:15, immediately after the 11:13:14 grant. TCC attributes the request to the main application through sandboxd, indicating filesystem access. Cleaner currently reads container metadata before excluding protected Apple ownership and recursively sizes caches. This is strong evidence for the scheduled scan, not a new MusicKit authorization request.

Exclude protected Apple/media data before opening metadata or traversing contents. Preserve ordinary third-party cache/leftover behavior and keep existing deletion safeguards. Never run actual cleanup or probe a real protected library to verify this change.

Accessory startup currently calls IOBluetooth and the shared battery sampler creates a CBCentralManager without preflight authorization. Gate every Bluetooth startup on a live grant; keep non-Bluetooth HID battery sampling available. The explicit accessory-enable action uses the shared cancellable permission activation flow. Reset/revocation switches that accessory option off, without switching unrelated feature settings off or automatically rearming after permission restoration.

## Verification

Approved seams: isolated filesystem fixtures and injected metadata reads; Bluetooth authorization/client-start boundaries; permission reset/recovery. Use RED before each behavior correction, focused suites, developer build, full regression suite and independent review. No real permission resets/requests, radio clients, hardware changes, or cleanup.
