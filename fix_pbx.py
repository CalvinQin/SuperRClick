import re

with open('SuperRClick.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# I will find all 'isa = PBXSourcesBuildPhase;' and inject the C3D9BB1899E340D9A777155C into them if not exists
build_phases = re.finditer(r'([A-F0-9]{24})\s*/\*\s*Sources\s*\*/\s*=\s*\{.*?isa\s*=\s*PBXSourcesBuildPhase;.*?files\s*=\s*\((.*?)\);', content, re.DOTALL)

for match in build_phases:
    phase_id = match.group(1)
    files_str = match.group(2)
    # create a unique id for this phase's new file
    import uuid
    new_uuid = uuid.uuid4().hex[:24].upper()
    
    # insert into PBXBuildFile
    buildfile_entry = f"{new_uuid} /* NewFileCatalog.swift in Sources */ = {{isa = PBXBuildFile; fileRef = 7592A14F9C604CB5982233DD /* NewFileCatalog.swift */; }};\n"
    content = content.replace('/* End PBXBuildFile section */', buildfile_entry + '/* End PBXBuildFile section */')
    
    # append to files list
    new_files_str = files_str + f"\n\t\t\t\t{new_uuid} /* NewFileCatalog.swift in Sources */,"
    content = content.replace(f"files = ({files_str});", f"files = ({new_files_str}\n\t\t\t);")

with open('SuperRClick.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)
