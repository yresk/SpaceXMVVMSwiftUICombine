//
//  LaunchesRepository.swift
//  SpaceXSwiftUI
//
//  Created by Martin Lukacs on 16/10/2020.
//

import Foundation
import Combine

protocol LaunchesRepositoryContract: class {
    var launches: CurrentValueSubject<Launches, Never> { get }
    var isLoadingContent: CurrentValueSubject<Bool, Never> { get }
    
    func deleteLaunch(by id: String)
    func refreshContent()
}

final class LaunchesRepository: LaunchesRepositoryContract {
    
    private let networkService: NetworkServiceContract
    private var cancellables = Set<AnyCancellable>()
    private(set) var launches: CurrentValueSubject<Launches, Never> = .init([])
    var isLoadingContent: CurrentValueSubject<Bool, Never> = .init(false)
    
    init(networkService: NetworkServiceContract) {
        self.networkService = networkService
        setUp()
    }
    
    func deleteLaunch(by id: String) {
        let filteredLaunches = launches.value.filter { $0.id != id }
        launches.send(filteredLaunches)
    }
    
    func refreshContent() {
        fetchLaunches()
    }
}

private extension LaunchesRepository {
    func setUp() {
        fetchLaunches()
    }
    
    func fetchLaunches() {
        guard !isLoadingContent.value else { return }
        isLoadingContent.send(true)
        launches(limit: nil, offset: nil)
            .replaceError(with: [])
            .share()
            .subscribe(on: DispatchQueue(label: "backgroundQueue"))
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoadingContent.send(false)
            }) { [weak self] newLaunches in
                self?.launches.send(newLaunches)
            }.store(in: &cancellables)
    }
    
    func launches(limit: Int?, offset: Int?) -> AnyPublisher<Launches, Error> {
        let endpoint = Endpoint.launches(limit: limit, offset: offset)
        
        return networkService.fetch(type: Launches.self,
                                   url: endpoint.url,
                                   headers: endpoint.headers!)
    }
    
    func launch(by flightNumber: Int) -> AnyPublisher<Launch, Error>{
        let endpoint = Endpoint.launch(by: flightNumber)
        
        return networkService.fetch(type: Launch.self,
                                   url: endpoint.url,
                                   headers: endpoint.headers!)
    }
}
