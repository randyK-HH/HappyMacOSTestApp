import Foundation

struct MemfaultRelease: Identifiable {
    let id: Int
    let version: String
    let createdDate: String
}

struct MemfaultPaging {
    let page: Int
    let pageCount: Int
    let totalCount: Int
}

struct MemfaultReleasesResponse {
    let releases: [MemfaultRelease]
    let paging: MemfaultPaging
}

final class MemfaultClient {
    private static let baseURL = "https://memfault.happy.dev"
    private static let chunksURL = "https://chunks.memfault.com/api/v0/chunks"
    private static let projectKey = "2xkNhje7HWN6cPIH2tBBwnwQB6paEsua"

    func uploadChunks(deviceSerial: String, chunks: [Data]) async throws -> Int {
        let boundary = "mflt-chunk-boundary-\(Int(Date().timeIntervalSince1970 * 1000))"
        let url = URL(string: "\(Self.chunksURL)/\(deviceSerial)")!

        var body = Data()
        for chunk in chunks {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n".data(using: .utf8)!)
            body.append("Content-Length: \(chunk.count)\r\n".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            body.append(chunk)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Self.projectKey, forHTTPHeaderField: "Memfault-Project-Key")
        request.setValue("multipart/mixed; boundary=\"\(boundary)\"", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode ?? -1
    }

    func fetchReleases(page: Int, perPage: Int = 20) async throws -> MemfaultReleasesResponse {
        let url = URL(string: "\(Self.baseURL)/releases?page=\(page)&per_page=\(perPage)")!

        var request = URLRequest(url: url)
        request.setValue(Self.projectKey, forHTTPHeaderField: "Memfault-Project-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else {
            throw NSError(domain: "MemfaultClient", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code) fetching releases"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let dataArray = json["data"] as? [[String: Any]] ?? []

        var releases = [MemfaultRelease]()
        for obj in dataArray {
            releases.append(MemfaultRelease(
                id: obj["id"] as? Int ?? 0,
                version: obj["version"] as? String ?? "",
                createdDate: obj["created_date"] as? String ?? ""
            ))
        }

        let pagingObj = json["paging"] as? [String: Any]
        let paging = MemfaultPaging(
            page: pagingObj?["page"] as? Int ?? page,
            pageCount: pagingObj?["page_count"] as? Int ?? 1,
            totalCount: pagingObj?["total_count"] as? Int ?? releases.count
        )

        return MemfaultReleasesResponse(releases: releases, paging: paging)
    }

    func fetchArtifactUrl(version: String) async throws -> String {
        let url = URL(string: "\(Self.baseURL)/releases/\(version)")!

        var request = URLRequest(url: url)
        request.setValue(Self.projectKey, forHTTPHeaderField: "Memfault-Project-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else {
            throw NSError(domain: "MemfaultClient", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code) fetching artifact for \(version)"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let dataObj = json["data"] as? [String: Any] ?? [:]
        let artifacts = dataObj["artifacts"] as? [[String: Any]] ?? []
        guard let firstArtifact = artifacts.first,
              let artifactUrl = firstArtifact["url"] as? String else {
            throw NSError(domain: "MemfaultClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No artifacts found for \(version)"])
        }
        return artifactUrl
    }

    func downloadArtifact(url: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: URL(string: url)!)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else {
            throw NSError(domain: "MemfaultClient", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code) downloading artifact"])
        }
        return data
    }
}
