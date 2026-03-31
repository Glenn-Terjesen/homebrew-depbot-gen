class DepbotGen < Formula
  desc "Scan git repos and generate GitHub Dependabot configuration"
  homepage "https://github.com/Glenn-Terjesen/homebrew-depbot-gen"
  url "https://github.com/Glenn-Terjesen/homebrew-depbot-gen/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "6a6e0cbe40b2ecaf189f082ceec57039bb7d2cfce0b28a3a76c22895f97a8c0e"
  license "MIT"

  depends_on "bash"

  def install
    bin.install "depbot-gen"
  end

  test do
    assert_match "depbot-gen", shell_output("#{bin}/depbot-gen --version")
  end
end
