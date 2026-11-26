<p align="center">
  <img src="assets/branding/blindfold-bandana.svg" width="96" height="96" alt="Blindfold app icon">
</p>
<h1 align="center">Blindfold</h1>
<p align="center">Clean your Mac without accidental input.</p>
<p align="center">
  <strong><a href="https://github.com/dvoyevoda/inputhush/releases/latest">Download for macOS</a></strong>
  · macOS 14 or later · <a href="LICENSE">MIT License</a>
</p>
<p align="center">
  <img src="assets/screenshots/cleaning-mode.png" width="420" alt="Blindfold’s Cleaning Mode window with four cleaning switches and the Start Cleaning button">
</p>

## Get started

1. Unzip the download, move **Blindfold.app** to **Applications**, and open it.
2. Choose what to pause and click **Start Cleaning**. For keyboard or pointer input, grant **Accessibility** and, if requested, **Input Monitoring** in **System Settings → Privacy & Security**.
3. Hold **Esc** for three seconds to finish, or let the auto-unlock timer expire. Choose **Never** for a session without a timer.

This release uses ad hoc signing and is distributed without Apple notarization. If macOS blocks the first launch, follow [Apple’s instructions for opening a trusted app](https://support.apple.com/en-us/102445#openanyway), or build from source below.

## Cleaning controls

- **Keyboard** pauses keystrokes and supported function-row controls.
- **Trackpad & Mouse** pauses pointer movement, clicks, and scrolling.
- **Display** blacks out every connected screen, with cleaning status visible on one.
- **Backlight** turns off the built-in keyboard lighting on supported Macs and restores it afterward.

Blindfold runs locally without telemetry. The power button and Touch ID stay under macOS control.

## Build from source

Use macOS 14 or later with Xcode or the Command Line Tools and Swift 6 or later.

```sh
git clone https://github.com/dvoyevoda/inputhush.git
cd inputhush
./scripts/build-app.sh
open .build/Blindfold.app
```

## Contributing

Report bugs in [GitHub Issues](https://github.com/dvoyevoda/inputhush/issues). To submit a change, fork the repo, run the [tests and relevant manual checks](docs/testing.md), then open a pull request against `main` with a summary and your test results.

## License

Blindfold is available under the [MIT License](LICENSE) and maintained by [@dvoyevoda](https://github.com/dvoyevoda).
