import Foundation

public enum NewFileCatalog {
    public static let templates: [(id: String, nameEN: String, nameZH: String, fileExtension: String, icon: String)] = [
        ("new-txt", "Text Document", "文本文档", "txt", "doc.plaintext"),
        ("new-md", "Markdown File", "Markdown 文件", "md", "doc"),
        ("new-rtf", "Rich Text File", "富文本文件", "rtf", "doc.richtext"),
        ("new-docx", "Word Document", "Word 文档", "docx", "doc.fill"),
        ("new-xlsx", "Excel Spreadsheet", "Excel 表格", "xlsx", "tablecells"),
        ("new-pptx", "PowerPoint Presentation", "PowerPoint 演示", "pptx", "play.rectangle"),
        ("new-swift", "Swift File", "Swift 文件", "swift", "swift"),
        ("new-py", "Python File", "Python 文件", "py", "chevron.left.forwardslash.chevron.right"),
        ("new-js", "JavaScript File", "JavaScript 文件", "js", "applescript"),
        ("new-ts", "TypeScript File", "TypeScript 文件", "ts", "applescript"),
        ("new-sh", "Shell Script", "Shell 脚本", "sh", "terminal"),
        ("new-java", "Java File", "Java 文件", "java", "cup.and.saucer"),
        ("new-cpp", "C++ File", "C++ 文件", "cpp", "c.square"),
        ("new-html", "HTML File", "HTML 文件", "html", "safari"),
        ("new-css", "CSS File", "CSS 文件", "css", "paintbrush"),
        ("new-xml", "XML File", "XML 文件", "xml", "chevron.left.forwardslash.chevron.right"),
        ("new-json", "JSON File", "JSON 文件", "json", "curlybraces.square"),
        ("new-csv", "CSV File", "CSV 文件", "csv", "tablecells")
    ]

    public static var all: [ActionDefinition] {
        templates.map { template in
            let name = SharedLocale.isChinese ? template.nameZH : template.nameEN
            return ActionDefinition(
                id: ActionID(rawValue: template.id),
                title: SharedLocale.isChinese ? "新建 \(name)" : "New \(template.nameEN)",
                subtitle: SharedLocale.isChinese ? "创建一个 .\(template.fileExtension) 文件" : "Create a new .\(template.fileExtension) file",
                systemImageName: template.icon,
                section: .newFile,
                sortOrder: 100,
                availability: ActionAvailability(
                    allowedContextKinds: [.finderSelection],
                    minimumSelectionCount: 0,
                    requiresFileItems: false
                )
            )
        }
    }
}
