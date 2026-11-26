# Testing Blindfold

## Automated tests

Run `swift test`. If the Command Line Tools report that `TestingMacros` is missing, load their bundled plugin explicitly.

```sh
swift test -Xswiftc -load-plugin-library \
  -Xswiftc "$(xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
```

## Manual checks

Start with the 30-second timer and a scratch document. Test one option at a time before trying them together.

| Option | What to check |
| --- | --- |
| Keyboard | Try typing, modifiers, F1–F12, the actions printed on those keys, and the same keys with Fn held. Try Option–Shift with brightness or volume, Command–Tab, Command–Space, and Shift–Command–4. Tap Esc and confirm cleaning continues, then hold it for three seconds to end the session. |
| Trackpad & Mouse | Try movement, clicks, and scrolling with the trackpad and an external mouse. Check that keyboard input is available. Hold Esc to restore the pointer. |
| Display | Confirm all connected screens turn black and one shows the status panel. Select **End Cleaning** to restore every display. |
| Backlight | On a supported Mac, confirm the built-in keyboard backlight goes dark and its previous brightness and automatic adjustment setting return afterward. |
| All options | Confirm a three-second Esc hold restores input, displays, and the supported backlight. |
| Auto-unlock | Confirm a timed session restores input on expiry. With **Never** selected, confirm cleaning stays active until you end it. |

For keyboard or pointer cleaning, grant **Accessibility** and, if requested, **Input Monitoring** under **System Settings → Privacy & Security**. If a rebuild loses access, remove the old entry and add the rebuilt `Blindfold.app`. Keep the app active when using Esc in a display-only session.

Record the macOS version, Mac model, and enabled options when reporting a problem. If pointer cleaning ends early, note whether Blindfold lost focus.
