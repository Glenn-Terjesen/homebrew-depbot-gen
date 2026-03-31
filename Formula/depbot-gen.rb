class DepbotGen < Formula
  desc "Scan git repos and generate GitHub Dependabot configuration"
  homepage "https://github.com/Glenn-Terjesen/depbot-gen"
  url "https://github.com/Glenn-Terjesen/depbot-gen/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
  license "MIT"

  depends_on "bash"

  def install
    bin.install "depbot-gen"
  end

  test do
    assert_match "depbot-gen", shell_output("#{bin}/depbot-gen --version")
  end
end
