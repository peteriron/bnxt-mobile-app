@testable import BNXT
import XCTest

final class APIConfigurationTests: XCTestCase {
    func testReadsKeyFromInfoDictionary() {
        let config = APIConfiguration(infoDictionary: ["BNXTAPIKey": " abc123 "])
        XCTAssertEqual(config?.apiKey, "abc123")
        XCTAssertEqual(config?.baseURL.absoluteString, "https://bnxt.sportpress.info/api/v1/")
    }

    /// A build without Secrets.xcconfig leaves the variable empty or unexpanded: no configuration.
    func testRejectsMissingEmptyOrUnexpandedKeys() {
        XCTAssertNil(APIConfiguration(infoDictionary: nil))
        XCTAssertNil(APIConfiguration(infoDictionary: [:]))
        XCTAssertNil(APIConfiguration(infoDictionary: ["BNXTAPIKey": ""]))
        XCTAssertNil(APIConfiguration(infoDictionary: ["BNXTAPIKey": "$(BNXT_API_KEY)"]))
        XCTAssertNil(APIConfiguration(infoDictionary: ["BNXTAPIKey": "paste-the-key-here"]))
        XCTAssertNil(APIConfiguration(infoDictionary: ["BNXTAPIKey": 42]))
    }

    func testSendsTheWebsitesAuthHeader() {
        XCTAssertEqual(APIConfiguration(apiKey: "k").headers["X-Authorization"], "k")
    }

    func testBuildsLiveStatsURL() {
        XCTAssertEqual(APIConfiguration(apiKey: "k").liveStatsURL(geniusId: 2_873_634).absoluteString,
                       "https://fibalivestats.dcd.shared.geniussports.com/data/2873634/data.json")
    }

    func testDescriptionNeverContainsTheKey() {
        let config = APIConfiguration(apiKey: "super-secret-key")
        XCTAssertFalse(String(describing: config).contains("super-secret-key"))
        XCTAssertFalse(config.description.contains("super-secret-key"))
    }
}
