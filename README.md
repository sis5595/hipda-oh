# HiPDA·OH

HiPDA·OH is a native HarmonyOS 6 client for the 4D4Y single-forum service.
It is built for current HarmonyOS devices and is validated on a Mate 60.

> Current repository status: private pre-release development. It is not an
> official 4D4Y product and is not yet an AppGallery release.

## What is implemented

- Forum browsing, pagination, pull-to-refresh, infinite loading, sorting, and pinned-thread visibility.
- Login through the forum's current web flow, plus multi-account switching.
- Thread reading, quote-floor navigation, attachments, images, original-image viewing, saving, sharing, zooming, and multi-image swiping.
- Quick reply, advanced reply, image upload, publishing, editing, and deleting the current user's posts where the forum permits it.
- Search, favourites, follows, blacklist, votes, messages, reminders, browsing history, and account settings.
- A native ArkUI interface designed against verified HiPDA NG interaction behaviour while using HarmonyOS-appropriate implementations.

The live forum remains the source of truth for permissions, forms, page structure,
and success/failure feedback. The app does not invent server-side protocol behaviour.
Authentication begins in the forum's ArkWeb flow. Where a feature requires native
transport (for example search, message lists, or image loading), it uses only the
current authenticated forum session for allowlisted 4D4Y endpoints; raw session
values are never written to logs, history, or exported data.

## Build locally

Requirements:

- DevEco Studio and the matching HarmonyOS 6 SDK/toolchain.
- A local signing configuration created for your own account/device.

Steps:

1. Copy `build-profile.example.json5` to `build-profile.json5`.
2. In DevEco Studio, open **File > Project Structure > Signing Configs** and create/select a local signing configuration for the `default` product.
3. Run the unit tests and package the application with the `hvigorw` supplied
   by your DevEco installation. On Windows, for example:

   ```powershell
   $devEcoHvigor = 'C:\Program Files\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
   & $devEcoHvigor test
   & $devEcoHvigor assembleHap
   ```

   Alternatively, build the `default` product from DevEco Studio after local
   signing has been configured.

`build-profile.json5`, certificates, provisioning files, keystores, generated HAPs,
and local reference projects are intentionally ignored by Git. Never commit them.

## License and notices

The project source is licensed under [GPL-3.0-or-later](LICENSE). The interface
uses a small set of Google Material Icons under Apache-2.0; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

HiPDA NG, MY 4D4Y, and Re:Source were used only as behaviour and compatibility
references during development. Their source code and assets are not included in
this repository.

## Before distributing a build

This private development repository does not substitute for a release review.
The remaining local and AppGallery checks are tracked in
[docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md), including the real
publisher identity and privacy-policy contact that must be supplied before any
public distribution.
