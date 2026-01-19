# xExplain Homebrew Formula
# To install: brew install xdev-asia-labs/tap/xexplain

class Xexplain < Formula
  desc "Explainable AI Framework for macOS System Intelligence"
  homepage "https://github.com/xdev-asia-labs/xExplain"
  url "https://github.com/xdev-asia-labs/xExplain/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on xcode: ["15.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/xExplain-CLI" => "xexplain"
  end

  test do
    assert_match "xExplain", shell_output("#{bin}/xexplain --version")
  end
end
