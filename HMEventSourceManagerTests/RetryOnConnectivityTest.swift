//
//  RetryOnConnectivityTest.swift
//  HMEventSourceManagerTests
//
//  Created by Hai Pham on 21/9/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import ReachabilitySwift
import RxReachability
import RxSwift
import RxTest
import SwiftUtilities
import SwiftUtilitiesTests
import XCTest
@testable import HMEventSourceManager

public final class RetryOnConnectivityTest: RootSSETest {
    public func test_internetReconnected_shouldRetryConnection() {
        /// Setup
        let observer = scheduler.createObserver([Event<Result>].self)
        let expect = expectation(description: "Should have completed")
        let disposeBag = self.disposeBag!
        let sseManager = self.newSSEManager()
        let terminateSbj = PublishSubject<Void>()
        var currentIteration = 0
        
        let request = HMSSEManager.Request.builder()
            .with(urlString: "MockURL")
            .build()
        
        let connectionObs = Observable<Event<Data>>.create({
            currentIteration += 1
            
            for _ in (0..<Int.max) {
                $0.onNext(Event<Data>.dummy)
            }
            
            return Disposables.create()
        })
        
        let sseFn: (Request) -> Observable<[Event<Result>]> = {
            sseManager.rx.reachabilityAwareSSE($0, connectionObs)
                .subscribeOn(qos: .background)
                .observeOn(qos: .background)
        }
        
        let waitTime: TimeInterval = 2
        let restartTimes = 10
        
        sseManager.rx.retryOnConnectivitySSE(request, sseFn)
            .takeUntil(terminateSbj)
            .doOnDispose(expect.fulfill)
            .subscribe(observer)
            .disposed(by: disposeBag)
        
        /// When
        let terminateTime = DispatchTime.now() + waitTime
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: terminateTime, execute: {
            for _ in 0..<restartTimes {
                // When reachable is false, old stream is terminated.
                sseManager.rx.triggerReachable.onNext(false)
                
                // When reachable is true, a new stream is started.
                sseManager.rx.triggerReachable.onNext(true)
            }
            
            // When this calls onNext, the stream will be terminated.
            terminateSbj.onNext(())
        })
        
        waitForExpectations(timeout: timeout, handler: nil)
        
        /// Then
        XCTAssertTrue(currentIteration > 0)
    }
}
