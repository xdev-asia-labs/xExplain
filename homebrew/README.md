# Homebrew Distribution

## Quick Install

```bash
brew install xdev-asia-labs/tap/xexplain
```

## Manual Install from Source

```bash
git clone https://github.com/xdev-asia-labs/xExplain.git
cd xExplain
swift build -c release
sudo cp .build/release/xExplain-CLI /usr/local/bin/xexplain
```

## Creating a Release

1. Tag the version:
```bash
git tag v1.0.0
git push origin v1.0.0
```

2. GitHub Actions will automatically:
   - Build universal binary (arm64 + x86_64)
   - Create GitHub Release with tarball
   - Generate SHA256 checksum

3. Update Homebrew tap with new SHA256

## Homebrew Tap Setup

Create a tap repository at `xdev-asia-labs/homebrew-tap` with the formula from `homebrew/xexplain.rb`.
