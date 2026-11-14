cask "super-rclick" do
  version "0.3.0-beta.2"
  sha256 "4c4a45a84a74b07ab7319775d475c91648faede235074a8cf5dc9ddc9a1fd8b1"

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
