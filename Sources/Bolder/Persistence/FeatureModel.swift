import Foundation

enum FeatureStatus: String, Codable, CaseIterable {
    case draft
    case planned
    case inProgress
    case done
    case cancelled
}

struct Feature: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var status: FeatureStatus
    var sourceNoteID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        status: FeatureStatus = .draft,
        sourceNoteID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.sourceNoteID = sourceNoteID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct FeaturesStore: Codable {
    var features: [Feature]

    init(features: [Feature] = []) {
        self.features = features
    }
}
