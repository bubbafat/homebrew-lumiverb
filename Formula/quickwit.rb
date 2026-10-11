class Quickwit < Formula
  desc "Search engine Lumiverb uses for its text search (Lumiverb runs it)"
  homepage "https://quickwit.io"
  if Hardware::CPU.arm?
    url "https://github.com/quickwit-oss/quickwit/releases/download/v0.8.2/quickwit-v0.8.2-aarch64-apple-darwin.tar.gz"
    sha256 "821e5638a1f927d2f3a85d211036026f4de9ec0c318a1708238c142a1328490e"
  else
    url "https://github.com/quickwit-oss/quickwit/releases/download/v0.8.2/quickwit-v0.8.2-x86_64-apple-darwin.tar.gz"
    sha256 "06b75268d80f6357ef6c4fddd1400a588f540444a734c0308423f793632e3b0a"
  end
  license "AGPL-3.0-only"

  # The brain (Linux) installs it with deploy-api.sh; prod runs 0.8.2 too.
  depends_on :macos

  def install
    bin.install "quickwit"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/quickwit --version")
  end
end
