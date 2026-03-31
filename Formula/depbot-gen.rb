class DepbotGen < Formula
  desc "Scan git repos and generate GitHub Dependabot configuration"
  homepage "https://github.com/Glenn-Terjesen/homebrew-depbot-gen"
  url "https://github.com/Glenn-Terjesen/homebrew-depbot-gen/archive/refs/tags/v1.0.2.tar.gz"
  sha256 "2dbf69611a899a119584dbe707597cadec760e537cb415849abecff6bbde0be2"
  license "MIT"

  depends_on "bash"

  def install
    bin.install "depbot-gen"
  end

  test do
    assert_match "depbot-gen", shell_output("#{bin}/depbot-gen --version")
  end
end
