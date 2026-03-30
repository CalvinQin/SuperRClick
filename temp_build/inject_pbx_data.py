import re
import uuid

with open('SuperRClick.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

if "NewFileData.swift" in content:
    print("Already exists")
    exit(0)

# 1. Generate IDs
def gen_id():
    return uuid.uuid4().hex[:24].upper()

file_ref_id = gen_id()
build_file_app_id = gen_id()
build_file_ext_id = gen_id()

# 2. Add to PBXBuildFile
build_file_block = fix_{build_file_app_id} /* NewFileData.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* NewFileData.swift */; }};
		{build_file_ext_id} /* NewFileData.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* NewFileData.swift */; }};
"""
content = content.replace("/* End PBXBuildFile section */", build_file_block + "/* End PBXBuildFile section */")

# 3. Add to PBXFileReference
ref_block = f'{file_ref_id} /* NewFileData.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NewFileData.swift; sourceTree = "<group>"; }};\n'
content = content.replace("/* End PBXFileReference section */", ref_block + "/* End PBXFileReference section */")

# 4. Add to Group (Actions group has path 'Actions' probably)
# Let's search for "NewFileCatalog.swift" to find its group and inject next to it.
group_match = re.search(r'([A-F0-9]{24})\s*/\*\s*NewFileCatalog\.swift\s*\*/\,', content)
if group_match:
    content = content.replace(group_match.group(0), group_match.group(0) + f'\n\t\t\t\t{file_ref_id} /* NewFileData.swift */,')

# 5. Add to Sources Build Phases
# 5a. Main App Sources phase
app_phase = re.search(r'([A-F0-9]{24})\s*/\*\s*Sources\s*\*/\s*=\s*\{[^{}]*?SuperRClickApp\.swift in Sources[^{}]*?\};', content)
if app_phase:
    old_app = app_phase.group(0)
    files_str = re.search(r'files\s*=\s*\((.*?)\);', old_app, re.DOTALL).group(1)
    new_app = old_app.replace(f"files = ({files_str});", f"files = ({files_str}\n\t\t\t\t{build_file_app_id} /* NewFileData.swift in Sources */,\n\t\t\t);")
    content = content.replace(old_app, new_app)

# 5b. FinderSync Extension Sources phase
ext_phase = re.search(r'([A-F0-9]{24})\s*/\*\s*Sources\s*\*/\s*=\s*\{[^{}]*?SuperRClickFinderSync\.swift in Sources[^{}]*?\};', content)
if ext_phase:
    old_ext = ext_phase.group(0)
    files_str_ext = re.search(r'files\s*=\s*\((.*?)\);', old_ext, re.DOTALL).group(1)
    new_ext = old_ext.replace(f"files = ({files_str_ext});", f"files = ({files_str_ext}\n\t\t\t\t{build_file_ext_id} /* NewFileData.swift in Sources */,\n\t\t\t);")
    content = content.replace(old_ext, new_ext)

with open('SuperRClick.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("Injected successfully.")
