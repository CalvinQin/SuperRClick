import re

with open('SuperRClick.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# First, remove `0A40DE0FC1E24C11AF9F839D /* ExtensionStatusBanner.swift in Sources */,`
content = content.replace("0A40DE0FC1E24C11AF9F839D /* ExtensionStatusBanner.swift in Sources */,", "")

# Now find the correct PBXSourcesBuildPhase for the main app.
# The main app target is "SuperRClick.app" or just look for the phase containing SuperRClickApp.swift exactly inside its { }
pattern = r'([A-F0-9]{24})\s*/\*\s*Sources\s*\*/\s*=\s*\{[^{}]*?SuperRClickApp\.swift in Sources[^{}]*?\};'
match = re.search(pattern, content)

if match:
    old_block = match.group(0)
    files_match = re.search(r'files\s*=\s*\((.*?)\);', old_block, re.DOTALL)
    if files_match:
        files_str = files_match.group(1)
        new_files_str = files_str + "\n\t\t\t\t0A40DE0FC1E24C11AF9F839D /* ExtensionStatusBanner.swift in Sources */,"
        new_block = old_block.replace(f"files = ({files_str});", f"files = ({new_files_str}\n\t\t\t);")
        content = content.replace(old_block, new_block)
        print("Success repairing PBXSourcesBuildPhase")

with open('SuperRClick.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)
