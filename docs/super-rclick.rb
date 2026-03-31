cask "super-rclick" do
  version "0.1.0"
  sha256 "e348eab068ee81cc1953c41389b6cc667dc802efa4a67db7f7adf307cc1054cd"

  url "https://github.com/CalvinQin/SuperRClick/releases/download/v#{version}/SuperRClick-v#{version}.dmg"
  name "Super RClick"
  desc "Finder right-click context menu enhancer for macOS"
  homepage "https://github.com/CalvinQin/SuperRClick"

  depends_on macos: ">= :sequoia"

  app "SuperRClick.app"

  zap trash: [
    "~/Library/Group Containers/group.com.haoqiqin.superrclick",
    "~/Library/Containers/com.haoqiqin.SuperRClick",
  ]
end
