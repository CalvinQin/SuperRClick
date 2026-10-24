cask "super-rclick" do
  version "0.3.0-beta.1"
  sha256 "8bce64c5ef6b9c01ae8a0c1b413977e04cee5496db1c750296cf2fe9ae0baabc"

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
