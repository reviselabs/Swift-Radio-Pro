//
//  PodcastRSSService.swift
//  SwiftRadio
//
//  RSS fetch/parsing for podcast feeds (e.g. SoundCloud).
//

import Foundation

enum PodcastRSSServiceError: Error {
    case invalidFeed
    case network(Error)
    case parseFailed
}

enum PodcastRSSService {
    private final class RSSParser: NSObject, XMLParserDelegate {
        private enum Target {
            case none
            case channelTitle
            case episodeTitle
            case episodePubDateRaw
            case episodeLink
            case episodeDuration
            case episodeDescription
            case episodeSummary
        }

        private struct EpisodeBuilder {
            var title: String?
            var description: String?
            var summary: String?
            var pubDateRaw: String?
            var pubDate: Date?
            var linkURL: URL?
            var audioURL: URL?
            var duration: String?
            var artworkURL: URL?
        }

        var channelTitle: String?
        var channelArtworkURL: URL?
        private(set) var episodes: [PodcastEpisode] = []

        private var itemDepth: Int = 0
        private var target: Target = .none

        private var currentText: String = ""
        private var currentEpisode: EpisodeBuilder?

        private static let rssDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            // Example: `Wed, 22 Apr 2026 09:24:34 +0000`
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }()

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
            currentText = ""
            let qualified = qName ?? elementName

            if qualified == "item" {
                itemDepth += 1
                currentEpisode = EpisodeBuilder()
                return
            }

            if itemDepth > 0 {
                if qualified == "title" {
                    target = .episodeTitle
                    return
                }
                if qualified == "pubDate" {
                    target = .episodePubDateRaw
                    return
                }
                if qualified == "link" {
                    target = .episodeLink
                    return
                }
                if qualified == "itunes:duration" || qualified.hasSuffix(":duration") || qualified == "duration" {
                    target = .episodeDuration
                    return
                }
                if qualified == "description" {
                    target = .episodeDescription
                    return
                }
                if qualified == "itunes:summary" || qualified.hasSuffix(":summary") {
                    target = .episodeSummary
                    return
                }

                if qualified == "enclosure", let urlString = attributes["url"], let url = URL(string: urlString) {
                    currentEpisode?.audioURL = url
                    return
                }

                // SoundCloud uses `<itunes:image href="..."/>`
                if let href = attributes["href"], (qualified == "image" || qualified.hasSuffix(":image")) {
                    currentEpisode?.artworkURL = URL(string: href)
                    return
                }
            } else {
                if qualified == "title" {
                    target = .channelTitle
                    return
                }

                // Channel-level artwork
                if let href = attributes["href"], (qualified == "image" || qualified.hasSuffix(":image")) {
                    if currentEpisode == nil {
                        channelArtworkURL = URL(string: href)
                    }
                    return
                }
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText.append(string)
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            if let text = String(data: CDATABlock, encoding: .utf8) {
                currentText.append(text)
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let qualified = qName ?? elementName

            switch target {
            case .channelTitle:
                if qualified == "title" {
                    channelTitle = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case .episodeTitle:
                if qualified == "title" {
                    currentEpisode?.title = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case .episodePubDateRaw:
                if qualified == "pubDate" {
                    let raw = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    currentEpisode?.pubDateRaw = raw
                    currentEpisode?.pubDate = Self.rssDateFormatter.date(from: raw)
                }
            case .episodeLink:
                if qualified == "link" {
                    let raw = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    currentEpisode?.linkURL = URL(string: raw)
                }
            case .episodeDuration:
                if qualified == "itunes:duration" || qualified == "duration" || qualified.hasSuffix(":duration") {
                    let raw = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    currentEpisode?.duration = raw.isEmpty ? nil : raw
                }
            case .episodeDescription:
                if qualified == "description" {
                    let raw = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    currentEpisode?.description = raw.isEmpty ? nil : raw.strippingHTMLTags
                }
            case .episodeSummary:
                if qualified == "itunes:summary" || qualified.hasSuffix(":summary") {
                    let raw = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    currentEpisode?.summary = raw.isEmpty ? nil : raw
                }
            case .none:
                break
            }

            if qualified == "item" {
                if let episode = makeEpisode(from: currentEpisode) {
                    episodes.append(episode)
                }
                itemDepth = max(0, itemDepth - 1)
                currentEpisode = nil
            }

            target = .none
            currentText = ""
        }

        private func makeEpisode(from builder: EpisodeBuilder?) -> PodcastEpisode? {
            guard let builder else { return nil }

            let title = builder.title ?? "Untitled Episode"
            let pubDateRaw = builder.pubDateRaw

            let id = builder.audioURL?.absoluteString ??
                builder.linkURL?.absoluteString ??
                pubDateRaw ??
                UUID().uuidString

            // Prefer plain-text summary over potentially HTML-heavy description
            let description = builder.summary ?? builder.description

            return PodcastEpisode(
                id: id,
                title: title,
                description: description,
                pubDate: builder.pubDate,
                pubDateRaw: pubDateRaw,
                linkURL: builder.linkURL,
                audioURL: builder.audioURL,
                duration: builder.duration,
                artworkURL: builder.artworkURL
            )
        }
    }

    static func fetchEpisodes(for podcast: Podcast) async throws -> (podcastTitle: String?, channelArtworkURL: URL?, episodes: [PodcastEpisode]) {
        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await URLSession.shared.data(from: podcast.feedURL)
        } catch {
            throw PodcastRSSServiceError.network(error)
        }

        let parser = XMLParser(data: data)
        let rssParser = RSSParser()
        parser.delegate = rssParser
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true

        guard parser.parse() else {
            throw PodcastRSSServiceError.parseFailed
        }

        return (rssParser.channelTitle, rssParser.channelArtworkURL, rssParser.episodes)
    }
}

private extension String {
    var strippingHTMLTags: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
