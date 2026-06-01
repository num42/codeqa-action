defmodule Test.Fixtures.Swift.ActorModel do
  @moduledoc false
  use Test.LanguageFixture, language: "swift actor_model"

  @code ~S'''
  enum ActorMessage {
    case ping(replyTo: String)
    case pong(from: String)
    case shutdown
    case updateState(key: String, value: String)
  }

  protocol ActorBehaviour {
    var id: String { get }
    func receive(_ message: ActorMessage) -> [ActorMessage]
    func preStart()
    func postStop()
  }

  struct ActorRef {
    let id: String
    private let mailbox: [ActorMessage]

    init(id: String) {
      self.id = id
      self.mailbox = []
    }
  }

  class ActorSystem {
    private var actors: [String: ActorBehaviour] = [:]
    private var mailboxes: [String: [ActorMessage]] = [:]

    func spawn(id: String, behaviour: ActorBehaviour) {
      actors[id] = behaviour
      mailboxes[id] = []
      behaviour.preStart()
    }

    func send(to id: String, message: ActorMessage) {
      mailboxes[id, default: []].append(message)
    }

    func process(actorId: String) {
      guard let actor = actors[actorId] else { return }
      let messages = mailboxes[actorId] ?? []
      mailboxes[actorId] = []
      for message in messages {
        let replies = actor.receive(message)
        for reply in replies { self.processReply(reply) }
      }
    }

    func stop(actorId: String) {
      actors[actorId]?.postStop()
      actors.removeValue(forKey: actorId)
      mailboxes.removeValue(forKey: actorId)
    }

    private func processReply(_ message: ActorMessage) {}
  }

  struct StateActor: ActorBehaviour {
    let id: String
    private var state: [String: String] = [:]

    func receive(_ message: ActorMessage) -> [ActorMessage] {
      switch message {
      case .ping(let replyTo): return [.pong(from: id)]
      case .updateState(let key, let value): return []
      case .shutdown: return []
      default: return []
      }
    }

    func preStart() {}

    func postStop() {}
  }
  '''
end
