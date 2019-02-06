import Foundation

// stream clients across app to share connections for the same destination
final class SharedStreamClients {
    static let shared = SharedStreamClients()
    private init() {}

    private var streamClients: [URL: StreamClient] = [:]

    func streamClient(_ instanceAccount: InstanceAccout) -> StreamClient {
        let k = instanceAccount.instance.baseURL!
        let sc = streamClients[k, default: StreamClient(instanceAccount: instanceAccount)]
        streamClients[k] = sc
        return sc
    }
}
