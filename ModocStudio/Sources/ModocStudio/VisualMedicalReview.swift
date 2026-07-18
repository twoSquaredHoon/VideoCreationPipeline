import Foundation
import SwiftUI

typealias VisualReviewVerdict = ScriptVerificationVerdict

struct VisualReviewIssue: Codable, Identifiable, Hashable {
    var id: String { (category ?? "") + (severity ?? "") + (note ?? "") + (timestampHint ?? "") }
    let category: String?
    let severity: String?
    let note: String?
    let timestampHint: String?

    enum CodingKeys: String, CodingKey {
        case category, severity, note
        case timestampHint = "timestamp_hint"
    }

    var issueSeverity: IssueSeverity { IssueSeverity(severity) }

    var categoryLabel: String {
        (category ?? "other")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

struct VisualMedicalReviewReport: Codable, Hashable {
    let verdict: VisualReviewVerdict
    let summary: String
    let issues: [VisualReviewIssue]
    let strengths: [String]
    let recommendedFixes: [String]
    let reviewedAt: String?
    let language: String?
    let blogURL: String?
    let videoPath: String?
    let projectPath: String?
    let model: String?

    enum CodingKeys: String, CodingKey {
        case verdict, summary, issues, strengths, model, language
        case recommendedFixes = "recommended_fixes"
        case reviewedAt = "reviewed_at"
        case blogURL = "blog_url"
        case videoPath = "video_path"
        case projectPath = "project_path"
    }

    /// Plain-text document suitable for pasting into email, Google Docs, etc.
    func plainTextDocument() -> String {
        var lines = [
            "MEDICAL VIDEO REVIEW",
            "====================",
            "",
            "Verdict: \(verdict.label.uppercased())",
            "Video: \(videoPath ?? "")",
            "Reviewed: \(reviewedAt ?? "")",
        ]
        if let blogURL, !blogURL.isEmpty { lines.append("Blog: \(blogURL)") }
        if let language, !language.isEmpty { lines.append("Language: \(language)") }
        lines += ["", "SUMMARY", "-------", summary, ""]

        if !issues.isEmpty {
            lines += ["ISSUES", "------"]
            for issue in issues {
                var prefix = "[\(issue.issueSeverity.label)] \(issue.categoryLabel)"
                if let hint = issue.timestampHint, !hint.isEmpty {
                    prefix += " @ \(hint)"
                }
                lines.append("• \(prefix)")
                lines.append("  \(issue.note ?? "")")
                lines.append("")
            }
            lines.append("")
        }

        if !strengths.isEmpty {
            lines += ["STRENGTHS", "---------"]
            for item in strengths { lines.append("• \(item)") }
            lines.append("")
        }

        if !recommendedFixes.isEmpty {
            lines += ["RECOMMENDED FIXES", "------------------"]
            for item in recommendedFixes { lines.append("• \(item)") }
            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
}

struct VisualReviewReportView: View {
    let report: VisualMedicalReviewReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: report.verdict.icon)
                    .foregroundStyle(report.verdict.color)
                Text(report.verdict.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(report.verdict.color)
                if let reviewedAt = report.reviewedAt, !reviewedAt.isEmpty {
                    Text(reviewedAt)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(report.summary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if !report.issues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Issues")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(report.issues) { issue in
                        HStack(alignment: .top, spacing: 8) {
                            Text(issue.issueSeverity.label)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(issue.issueSeverity.color)
                                .frame(width: 52, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.categoryLabel)
                                    .font(.caption.weight(.semibold))
                                Text(issue.note ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let hint = issue.timestampHint, !hint.isEmpty {
                                    Text(hint)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }

            if !report.strengths.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Strengths")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(report.strengths, id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                    }
                }
            }

            if !report.recommendedFixes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended fixes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(report.recommendedFixes, id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                    }
                }
            }
        }
    }
}
