import Foundation

class GeminiService {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    func generateTestCases(userStory: String, scenarios: String, apiKey: String, model: String) async throws -> GeneratedSuite {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmedKey.isEmpty else { throw GeminiError.missingAPIKey }
        guard let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(trimmedKey)") else { throw GeminiError.invalidURL }

        let prompt = buildPrompt(userStory: userStory, scenarios: scenarios)
        let requestBody = GeminiRequest(
            contents: [.init(parts: [.init(text: prompt)])],
            generationConfig: .init(responseMimeType: "application/json")
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw GeminiError.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 400: throw GeminiError.invalidAPIKey
        case 429: throw GeminiError.rateLimited
        default:  throw GeminiError.apiError(http.statusCode)
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.emptyResponse
        }

        return try parseSuite(from: text, userStory: userStory, scenarios: scenarios)
    }

    // MARK: - Prompt

    private func buildPrompt(userStory: String, scenarios: String) -> String {
        let scenariosSection = scenarios.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "" : "\nScenarios:\n\(scenarios)"

        return """
        You are a senior QA engineer. Generate thorough test cases for the user story below.

        Return ONLY a raw JSON object — no markdown, no code fences, no explanation:
        {
          "suiteName": "Short descriptive name for this test suite",
          "positiveTestCases": [
            {
              "title": "TC-P01: Descriptive title",
              "steps": ["Step 1", "Step 2", "Step 3"],
              "expectedResult": "Specific verifiable outcome"
            }
          ],
          "negativeTestCases": [
            {
              "title": "TC-N01: Descriptive title",
              "steps": ["Step 1", "Step 2"],
              "expectedResult": "Specific error or failure behavior expected"
            }
          ]
        }

        Rules:
        - At least 5 positive test cases (happy paths, valid inputs, boundary values)
        - At least 4 negative test cases (invalid inputs, edge cases, error states)
        - 2–5 clear actionable steps per test case
        - Expected results must be specific and testable

        User Story: \(userStory)\(scenariosSection)
        """
    }

    // MARK: - Parsing

    private func parseSuite(from text: String, userStory: String, scenarios: String) throws -> GeneratedSuite {
        // Strip any accidental markdown fences Gemini might still add
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
        }

        guard let data = cleaned.data(using: .utf8) else { throw GeminiError.parseError }
        let parsed = try JSONDecoder().decode(GeminiParsedSuite.self, from: data)

        let positive = parsed.positiveTestCases.map {
            GeneratedTestCase(title: $0.title, type: .positive, steps: $0.steps, expectedResult: $0.expectedResult)
        }
        let negative = parsed.negativeTestCases.map {
            GeneratedTestCase(title: $0.title, type: .negative, steps: $0.steps, expectedResult: $0.expectedResult)
        }

        return GeneratedSuite(
            name: parsed.suiteName,
            date: Date(),
            userStory: userStory,
            scenarios: scenarios,
            testCases: positive + negative
        )
    }
}

// MARK: - API request/response models

private struct GeminiRequest: Encodable {
    let contents: [Content]
    let generationConfig: GenerationConfig

    struct Content: Encodable {
        let parts: [Part]
        struct Part: Encodable { let text: String }
    }
    struct GenerationConfig: Encodable {
        let responseMimeType: String
    }
}

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]
    struct Candidate: Decodable {
        let content: Content
        struct Content: Decodable {
            let parts: [Part]
            struct Part: Decodable { let text: String }
        }
    }
}

private struct GeminiParsedSuite: Decodable {
    let suiteName: String
    let positiveTestCases: [ParsedCase]
    let negativeTestCases: [ParsedCase]

    struct ParsedCase: Decodable {
        let title: String
        let steps: [String]
        let expectedResult: String
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case missingAPIKey, invalidURL, invalidResponse
    case invalidAPIKey, rateLimited, apiError(Int)
    case emptyResponse, parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:      return "Please enter your Gemini API key."
        case .invalidURL:         return "Invalid API URL."
        case .invalidResponse:    return "Invalid response from Gemini API."
        case .invalidAPIKey:      return "Invalid API key — check it at aistudio.google.com/app/apikey."
        case .rateLimited:        return "Rate limit reached. Wait a moment and try again."
        case .apiError(let code): return "Gemini API error (HTTP \(code))."
        case .emptyResponse:      return "Gemini returned an empty response."
        case .parseError:         return "Could not parse Gemini response. Try again."
        }
    }
}
