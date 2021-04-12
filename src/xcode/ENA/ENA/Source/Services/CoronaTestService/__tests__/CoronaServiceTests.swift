//
// 🦠 Corona-Warn-App
//

@testable import ENA
import ExposureNotification
import XCTest

class CoronaServiceTests: XCTestCase {

	// MARK: - Test Result

	func testUpdatePCRTestResult_success() {
		let client = ClientMock()
		client.onGetTestResult = { _, _, completion in
			completion(.success(TestResult.positive.rawValue))
		}

		let service = CoronaTestService(client: client, store: MockTestStore())
		service.pcrTest = PCRTest.mock(registrationToken: "regToken")

		let expectation = self.expectation(description: "Expect to receive a result.")

		service.updateTestResult(for: .pcr) { result in
			expectation.fulfill()
			switch result {
			case .failure:
				XCTFail("This test should always return a successful result.")
			case .success(let testResult):
				XCTAssertEqual(testResult, TestResult.positive)
			}
		}

		waitForExpectations(timeout: .short)

		guard let pcrTest = service.pcrTest else {
			XCTFail("pcrTest should not be nil")
			return
		}

		XCTAssertEqual(pcrTest.testResult, .positive)
		XCTAssertEqual(
			try XCTUnwrap(pcrTest.testResultReceivedDate).timeIntervalSince1970,
			Date().timeIntervalSince1970,
			accuracy: 10
		)
	}

	func testUpdateAntigenTestResult_success() {
		let client = ClientMock()
		client.onGetTestResult = { _, _, completion in
			completion(.success(TestResult.positive.rawValue))
		}

		let service = CoronaTestService(client: client, store: MockTestStore())
		service.antigenTest = AntigenTest.mock(registrationToken: "regToken")

		let expectation = self.expectation(description: "Expect to receive a result.")

		service.updateTestResult(for: .antigen) { result in
			expectation.fulfill()
			switch result {
			case .failure:
				XCTFail("This test should always return a successful result.")
			case .success(let testResult):
				XCTAssertEqual(testResult, TestResult.positive)
			}
		}

		waitForExpectations(timeout: .short)

		guard let antigenTest = service.antigenTest else {
			XCTFail("antigenTest should not be nil")
			return
		}

		XCTAssertEqual(antigenTest.testResult, .positive)
		XCTAssertEqual(
			try XCTUnwrap(antigenTest.testResultReceivedDate).timeIntervalSince1970,
			Date().timeIntervalSince1970,
			accuracy: 10
		)
	}

	func testUpdatePCRTestResult_noCoronaTestOfRequestedType() {
		let service = CoronaTestService(client: ClientMock(), store: MockTestStore())
		service.pcrTest = nil

		let expectation = self.expectation(description: "Expect to receive a result.")

		service.updateTestResult(for: .pcr) { result in
			expectation.fulfill()
			switch result {
			case .failure(let error):
				XCTAssertEqual(error, .noCoronaTestOfRequestedType)
			case .success:
				XCTFail("This test should always fail since the registration token is missing.")
			}
		}

		waitForExpectations(timeout: .short)
	}

	func testUpdateAntigenTestResult_noCoronaTestOfRequestedType() {
		let service = CoronaTestService(client: ClientMock(), store: MockTestStore())
		service.antigenTest = nil

		let expectation = self.expectation(description: "Expect to receive a result.")

		service.updateTestResult(for: .antigen) { result in
			expectation.fulfill()
			switch result {
			case .failure(let error):
				XCTAssertEqual(error, .noCoronaTestOfRequestedType)
			case .success:
				XCTFail("This test should always fail since the registration token is missing.")
			}
		}

		waitForExpectations(timeout: .short)
	}

	func testUpdatePCRTestResult_noRegistrationToken() {
		let service = CoronaTestService(client: ClientMock(), store: MockTestStore())
		service.pcrTest = PCRTest.mock(registrationToken: nil)

		let expectation = self.expectation(description: "Expect to receive a result.")

		service.updateTestResult(for: .pcr) { result in
			expectation.fulfill()
			switch result {
			case .failure(let error):
				XCTAssertEqual(error, .noRegistrationToken)
			case .success:
				XCTFail("This test should always fail since the registration token is missing.")
			}
		}

		waitForExpectations(timeout: .short)

		guard let pcrTest = service.pcrTest else {
			XCTFail("pcrTest should not be nil")
			return
		}

		XCTAssertEqual(pcrTest.testResult, .pending)
		XCTAssertNil(pcrTest.testResultReceivedDate)
	}

	func testUpdateAntigenTestResult_noRegistrationToken() {
		let service = CoronaTestService(client: ClientMock(), store: MockTestStore())
		service.antigenTest = AntigenTest.mock(registrationToken: nil)

		let expectation = self.expectation(description: "Expect to receive a result.")

		service.updateTestResult(for: .antigen) { result in
			expectation.fulfill()
			switch result {
			case .failure(let error):
				XCTAssertEqual(error, .noRegistrationToken)
			case .success:
				XCTFail("This test should always fail since the registration token is missing.")
			}
		}

		waitForExpectations(timeout: .short)

		guard let antigenTest = service.antigenTest else {
			XCTFail("antigenTest should not be nil")
			return
		}

		XCTAssertEqual(antigenTest.testResult, .pending)
		XCTAssertNil(antigenTest.testResultReceivedDate)
	}

	// MARK: - Test Registration

	func testRegisterPCRTestAndGetResult_successWithoutSubmissionConsentGiven() {
		let store = MockTestStore()
		store.enfRiskCalculationResult = mockRiskCalculationResult()

		Analytics.setupMock(store: store)
		store.isPrivacyPreservingAnalyticsConsentGiven = true

		let client = ClientMock()
		client.onGetRegistrationToken = { _, _, _, completion in
			completion(.success("registrationToken"))
		}

		client.onGetTestResult = { _, _, completion in
			completion(.success(TestResult.pending.rawValue))
		}

		let service = CoronaTestService(client: client, store: store)
		service.pcrTest = nil

		let expectation = self.expectation(description: "Expect to receive a result.")

		service.registerPCRTestAndGetResult(
			guid: "guid",
			isSubmissionConsentGiven: false
		) { result in
			expectation.fulfill()
			switch result {
			case .failure:
				XCTFail("This test should always return a successful result.")
			case .success(let testResult):
				XCTAssertEqual(testResult, TestResult.pending)
			}
		}

		waitForExpectations(timeout: .short)

		guard let pcrTest = service.pcrTest else {
			XCTFail("pcrTest should not be nil")
			return
		}

		XCTAssertEqual(pcrTest.registrationToken, "registrationToken")
		XCTAssertEqual(
			try XCTUnwrap(pcrTest.registrationDate).timeIntervalSince1970,
			Date().timeIntervalSince1970,
			accuracy: 10
		)
		XCTAssertEqual(pcrTest.testResult, .pending)
		XCTAssertNil(pcrTest.testResultReceivedDate)
		XCTAssertFalse(pcrTest.positiveTestResultWasShown)
		XCTAssertFalse(pcrTest.isSubmissionConsentGiven)
		XCTAssertNil(pcrTest.submissionTAN)
		XCTAssertFalse(pcrTest.keysSubmitted)
		XCTAssertFalse(pcrTest.journalEntryCreated)

		XCTAssertEqual(store.testResultMetadata?.testResult, .pending)
		XCTAssertEqual(
			try XCTUnwrap(store.testResultMetadata?.testRegistrationDate).timeIntervalSince1970,
			Date().timeIntervalSince1970,
			accuracy: 10
		)
	}

	func testRegisterPCRTestAndGetResult_successWithSubmissionConsentGiven() {
		let store = MockTestStore()
		store.enfRiskCalculationResult = mockRiskCalculationResult()

		Analytics.setupMock(store: store)
		store.isPrivacyPreservingAnalyticsConsentGiven = true

		let client = ClientMock()
		client.onGetRegistrationToken = { _, _, _, completion in
			completion(.success("registrationToken2"))
		}

		client.onGetTestResult = { _, _, completion in
			completion(.success(TestResult.negative.rawValue))
		}

		let service = CoronaTestService(client: client, store: store)
		service.pcrTest = nil

		let expectation = self.expectation(description: "Expect to receive a result.")

		service.registerPCRTestAndGetResult(
			guid: "guid",
			isSubmissionConsentGiven: true
		) { result in
			expectation.fulfill()
			switch result {
			case .failure:
				XCTFail("This test should always return a successful result.")
			case .success(let testResult):
				XCTAssertEqual(testResult, TestResult.negative)
			}
		}

		waitForExpectations(timeout: .short)

		guard let pcrTest = service.pcrTest else {
			XCTFail("pcrTest should not be nil")
			return
		}

		XCTAssertEqual(pcrTest.registrationToken, "registrationToken2")
		XCTAssertEqual(
			try XCTUnwrap(pcrTest.registrationDate).timeIntervalSince1970,
			Date().timeIntervalSince1970,
			accuracy: 10
		)
		XCTAssertEqual(pcrTest.testResult, .negative)
		XCTAssertEqual(
			try XCTUnwrap(pcrTest.testResultReceivedDate).timeIntervalSince1970,
			Date().timeIntervalSince1970,
			accuracy: 10
		)
		XCTAssertFalse(pcrTest.positiveTestResultWasShown)
		XCTAssertTrue(pcrTest.isSubmissionConsentGiven)
		XCTAssertNil(pcrTest.submissionTAN)
		XCTAssertFalse(pcrTest.keysSubmitted)
		XCTAssertFalse(pcrTest.journalEntryCreated)

		XCTAssertEqual(store.testResultMetadata?.testResult, .negative)
		XCTAssertEqual(
			try XCTUnwrap(store.testResultMetadata?.testRegistrationDate).timeIntervalSince1970,
			Date().timeIntervalSince1970,
			accuracy: 10
		)
	}

	// MARK: - Plausible Deniability

	func test_getTestResultPlaybookPositive() {
		getTestResultPlaybookTest(for: .pcr, with: .positive)
		getTestResultPlaybookTest(for: .antigen, with: .positive)
	}

	func test_getTestResultPlaybookNegative() {
		getTestResultPlaybookTest(for: .pcr, with: .negative)
		getTestResultPlaybookTest(for: .antigen, with: .negative)
	}

	func test_getTestResultPlaybookPending() {
		getTestResultPlaybookTest(for: .pcr, with: .pending)
		getTestResultPlaybookTest(for: .antigen, with: .pending)
	}

	func test_getTestResultPlaybookInvalid() {
		getTestResultPlaybookTest(for: .pcr, with: .invalid)
		getTestResultPlaybookTest(for: .antigen, with: .invalid)
	}

	func test_getTestResultPlaybookExpired() {
		getTestResultPlaybookTest(for: .pcr, with: .expired)
		getTestResultPlaybookTest(for: .antigen, with: .expired)
	}

	// MARK: - Private

	private func getTestResultPlaybookTest(for coronaTestType: CoronaTestType, with testResult: TestResult) {
		// Counter to track the execution order.
		var count = 0

		let expectation = self.expectation(description: "execute all callbacks")
		expectation.expectedFulfillmentCount = 4

		// Initialize.

		let client = ClientMock()

		client.onGetTestResult = { _, isFake, completion in
			expectation.fulfill()
			XCTAssertFalse(isFake)
			XCTAssertEqual(count, 0)
			count += 1
			completion(.success(testResult.rawValue))
		}

		client.onGetTANForExposureSubmit = { _, isFake, completion in
			expectation.fulfill()
			XCTAssertTrue(isFake)
			XCTAssertEqual(count, 1)
			count += 1
			completion(.failure(.fakeResponse))
		}

		client.onSubmitCountries = { _, isFake, completion in
			expectation.fulfill()
			XCTAssertTrue(isFake)
			XCTAssertEqual(count, 2)
			count += 1
			completion(.success(()))
		}

		let service = CoronaTestService(client: client, store: MockTestStore())
		service.pcrTest = PCRTest.mock(registrationToken: "regToken")
		service.antigenTest = AntigenTest.mock(registrationToken: "regToken")

		// Run test.

		service.updateTestResult(for: coronaTestType) { response in
			switch response {
			case .failure(let error):
				XCTFail(error.localizedDescription)
			case .success(let result):
				XCTAssertEqual(result.rawValue, testResult.rawValue)
			}

			expectation.fulfill()
		}

		waitForExpectations(timeout: .short)
	}

 	private func mockRiskCalculationResult() -> ENFRiskCalculationResult {
 		ENFRiskCalculationResult(
 			riskLevel: .high,
 			minimumDistinctEncountersWithLowRisk: 0,
 			minimumDistinctEncountersWithHighRisk: 0,
 			mostRecentDateWithLowRisk: Date(),
 			mostRecentDateWithHighRisk: Date(),
 			numberOfDaysWithLowRisk: 0,
 			numberOfDaysWithHighRisk: 2,
 			calculationDate: Date(),
 			riskLevelPerDate: [:],
 			minimumDistinctEncountersWithHighRiskPerDate: [:]
 		)
 	}

}
