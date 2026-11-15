cask "super-rclick" do
  version "0.3.0-beta.3"
  sha256 "5a91e83a7b92cb4f0003781cba615cab48b5858f38ae32b7cd7bd25f1d0c4bd5"

  url "https://github.com/CalvinQin/SuperRClick/releases/download/v#{version}/SuperRClick-#{version}.dmg"
  name "Super RClick"
  desc "Finder right-click context menu enhancer for macOS"
  homepage "https://calvinqin.github.io/SuperRClick/"

  depends_on macos: ">= :sequoia"

  app "SuperRClick.app"

  zap trash: [
    "~/Library/Group Containers/group.com.haoqiqin.superrclick",
    "~/Library/Containers/com.haoqiqin.SuperRClick",
  ]
end
