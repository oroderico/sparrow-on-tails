# sparrow-on-tails

Installs [Sparrow Wallet](https://sparrowwallet.com/) persistently on [Tails](https://tails.net/), always fetching the latest official release and verifying it before installing.

> ⚠️ **Not a recommendation.** This is one possible way to run Sparrow on Tails, not the only or the "correct" one. Evaluate for yourself whether you actually need to store wallet data persistently — if you don't, consider Watch-Only mode instead. If you do keep data on the device, **never** connect that device to the internet unless you fully understand the tradeoffs.
>
> This project does not cover installing or configuring Tails itself.

## What the script does

`install-sparrow-tails.sh` automates the install steps:

1. Looks up the latest Sparrow release on GitHub (never a hardcoded version).
2. Downloads the release tarball, its manifest, and the manifest's PGP signature.
3. Imports the developer's (Craig Raw) PGP key and checks its fingerprint against a pinned value, so a spoofed key can't pass verification.
4. Verifies the manifest's PGP signature and the tarball's SHA-256 checksum.
5. Installs the app under `~/Persistent/SW/Sparrow`, keeping wallet data in a separate `~/Persistent/SW/data` directory so re-running the script to upgrade never touches existing wallet data.
6. Adds a Sparrow shortcut to the Tails application menu (persisted via dotfiles).

If any verification step fails, nothing is installed.

## Prerequisites (manual, done in the Tails GUI before running the script)

- **Administration Password** enabled on the Tails welcome screen (needed for the `sudo` steps).
- **Persistent Storage** with *Persistent Folder* and *Dotfiles* enabled.

## Usage

Download the script, make it executable and run it:

```sh
curl -fsSLO https://raw.githubusercontent.com/oroderico/sparrow-on-tails/main/install-sparrow-tails.sh && chmod +x install-sparrow-tails.sh && ./install-sparrow-tails.sh
```

This project is about verifying things before trusting them, so before running it, take a look at what the script actually does — it stays on disk as `install-sparrow-tails.sh` afterward, so you can open and read it any time.

After it finishes, you'll be asked whether to reboot Tails (required for the shortcut to appear in the app menu). Once rebooted, open Sparrow and set the Tor proxy under **Preferences → Server** (`127.0.0.1:9050`).

## Credits

This guide/script is based on the original work by [Daniel Costas](https://danielpcostas.dev/installing-sparrow-wallet-on-tailsos-persistently/), adapted, translated and extended by [oroderico](https://github.com/oroderico) with additional automation (automatic latest-version detection, PGP fingerprint pinning, checksum verification, and persistent-data separation).

Thanks to [**K3zeus**](https://github.com/K3zeus) for the introduction to Linux and free/secure systems, and to [**Sandmann**](https://github.com/sandman21vs) for guidance on hardware wallets and digital sovereignty.

## License

[MIT](LICENSE)
