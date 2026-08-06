import Foundation

struct ProjectGroup: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    /// Project folder paths (VideoProject.id).
    var projectIDs: [String]

    init(id: String = UUID().uuidString, name: String, projectIDs: [String] = []) {
        self.id = id
        self.name = name
        self.projectIDs = projectIDs
    }
}

struct ProjectGroupsFile: Codable {
    var groups: [ProjectGroup]
    var selectedGroupID: String?

    static let ungroupedID = "__ungrouped__"

    static var empty: ProjectGroupsFile {
        ProjectGroupsFile(groups: [], selectedGroupID: ungroupedID)
    }
}

enum ProjectGroupsStore {
    static var fileURL: URL {
        ModocConfig.projectsURL.appendingPathComponent("project_groups.json")
    }

    static func load() -> ProjectGroupsFile {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(ProjectGroupsFile.self, from: data) else {
            return .empty
        }
        return file
    }

    static func save(_ file: ProjectGroupsFile) throws {
        try FileManager.default.createDirectory(
            at: ModocConfig.projectsURL,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: .atomic)
    }
}
