import Foundation
import Mockable
import Path
import ServiceContextModule
import TuistCache
import TuistCore
import TuistLoader
import TuistServer
import TuistSupport
import XcodeProj
import XCTest
@testable import TuistCoreTesting
@testable import TuistKit
@testable import TuistLoaderTesting
@testable import TuistSupportTesting

final class GenerateServiceTests: TuistUnitTestCase {
    private var subject: GenerateService!
    private var opener: MockOpening!
    private var generator: MockGenerating!
    private var generatorFactory: MockGeneratorFactorying!
    private var cacheStorageFactory: MockCacheStorageFactorying!
    private var clock: StubClock!

    override func setUp() {
        super.setUp()
        opener = .init()
        generator = .init()
        generatorFactory = .init()
        given(generatorFactory)
            .generation(
                config: .any,
                includedTargets: .any,
                configuration: .any,
                ignoreBinaryCache: .any,
                cacheStorage: .any
            )
            .willReturn(generator)
        cacheStorageFactory = .init()
        given(cacheStorageFactory)
            .cacheStorage(config: .any)
            .willReturn(MockCacheStoring())
        clock = StubClock()
        subject = GenerateService(
            cacheStorageFactory: cacheStorageFactory,
            generatorFactory: generatorFactory,
            clock: clock,
            opener: opener
        )
    }

    override func tearDown() {
        opener = nil
        generator = nil
        generatorFactory = nil
        cacheStorageFactory = nil
        clock = nil
        subject = nil
        super.tearDown()
    }

    func test_run_fatalErrors_when_theworkspaceGenerationFails() async throws {
        let expectedError = NSError.test()
        given(generator)
            .generateWithGraph(path: .any)
            .willThrow(expectedError)

        do {
            try await subject
                .run(
                    path: nil,
                    includedTargets: [],
                    noOpen: true,
                    configuration: nil,
                    ignoreBinaryCache: false
                )
            XCTFail("Must throw")
        } catch {
            XCTAssertEqual(error as NSError?, expectedError)
        }
    }

    func test_run() async throws {
        // Given
        let workspacePath = try AbsolutePath(validating: "/test.xcworkspace")
        let environment = MapperEnvironment()
        given(generator)
            .generateWithGraph(path: .any)
            .willReturn(
                (
                    workspacePath,
                    .test(),
                    environment
                )
            )

        given(opener)
            .open(path: .any)
            .willReturn()

        // When
        try await subject.run(
            path: nil,
            includedTargets: [],
            noOpen: false,
            configuration: nil,
            ignoreBinaryCache: false
        )

        // Then
        verify(opener)
            .open(path: .value(workspacePath))
            .called(1)
    }

    func test_run_timeIsPrinted() async throws {
        try await ServiceContext.withTestingDependencies {
            // Given
            let workspacePath = try AbsolutePath(validating: "/test.xcworkspace")

            given(opener)
                .open(path: .any)
                .willReturn()

            given(generator)
                .generateWithGraph(path: .any)
                .willReturn((workspacePath, .test(), MapperEnvironment()))
            clock.assertOnUnexpectedCalls = true
            clock.primedTimers = [
                0.234,
            ]

            // When
            try await subject.run(
                path: nil,
                includedTargets: [],
                noOpen: false,
                configuration: nil,
                ignoreBinaryCache: false
            )

            // Then
            XCTAssertPrinterOutputContains("Total time taken: 0.234s")
        }
    }
}
