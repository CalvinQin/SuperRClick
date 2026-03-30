import re
import uuid

with open('SuperRClick.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Add to PBXBuildFile
new_build_uuid = uuid.uuid4().hex[:24].upper()
new_fileref_uuid = uuid.uuid4().hex[:24].upper()

fileref = f"{new_fileref_uuid} /* ExtensionStatusBanner.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ExtensionStatusBanner.swift; sourceTree = \"<group>\"; }};\n"
buildfile = f"{new_build_uuid} /* ExtensionStatusBanner.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {new_fileref_uuid} /* ExtensionStatusBanner.swift */; }};\n"

content = content.replace('/* End PBXFileReference section */', fileref + '/* End PBXFileReference section */')
content = content.replace('/* End PBXBuildFile section */', buildfile + '/* End PBXBuildFile section */')

# Add to the App/Features/Settings group
match_group = re.search(r'([A-F0-9]{24})\s*/\*\s*Settings\s*\*/\s*=\s*\{.*?children\s*=\s*\((.*?)\);', content, re.DOTALL)
if match_group:
    children_str = match_group.group(2)
    new_children_str = children_str + f"\n\t\t\t\t{new_fileref_uuid} /* ExtensionStatusBanner.swift */,"
    content = content.replace(f"children = ({children_str});", f"children = ({new_children_str}\n\t\t\t);")

# Add to the SuperRClick main app target's PBXSourcesBuildPhase
# Main app sources phase is usually the one with SuperRClickApp.swift
match_phase = re.search(r'([A-F0-9]{24})\s*/\*\s*Sources\s*\*/\s*=\s*\{[^\}]*?isa\s*=\s*PBXSourcesBuildPhase;.*?SuperRClickApp\.swift in Sources.*?\};', content, re.DOTALL)
if match_phase:
    phase_str = match_phase.group(0)
    files_match = re.search(r'files\s*=\s*\((.*?)\);', phase_str, re.DOTALL)
    if files_match:
        files_str = files_match.group(1)
        new_files_str = files_str + f"\n\t\t\t\t{new_build_uuid} /* ExtensionStatusBanner.swift in Sources */,"
        new_phase_str = phase_str.replace(f"files = ({files_str});", f"files = ({new_files_str}\n\t\t\t);")
        content = content.replace(phase_str, new_phase_str)

with open('SuperRClick.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)
