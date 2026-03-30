import json

files = ['docx', 'xlsx', 'pptx']
swift_code = "public enum NewFileData {\n    public static let base64Templates: [String: String] = [\n"

for f in files:
    with open(f"temp_build/{f}_b64.txt", "r") as txt:
        data = txt.read().strip()
        swift_code += f'        "{f}": "{data}",\n'

swift_code += "    ]\n}\n"

with open("Shared/Actions/NewFileData.swift", "w") as out:
    out.write(swift_code)
print("NewFileData.swift generated successfully!")
