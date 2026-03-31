class DepbotGen < Formula
  desc "Scan git repos and generate GitHub Dependabot configuration"
  homepage "https://github.com/Glenn-Terjesen/depbot-gen"
  url "https://github.com/Glenn-Terjesen/depbot-gen/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER"
  license "MIT"

  depends_on "bash"

  def install
    bin.install "depbot-gen"
  end

  test do
    assert_match "depbot-gen", shell_output("#{bin}/depbot-gen --version")
  end
end
