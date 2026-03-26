defmodule Test.Fixtures.Scala.ActorMessages do
  @moduledoc false
  use Test.LanguageFixture, language: "scala actor_messages"

  @code ~S'''
  trait Message

  class Request(val id: String, val payload: Map[String, String]) extends Message

  class Response(val id: String, val status: Int, val body: String) extends Message

  class Broadcast(val topic: String, val data: String) extends Message

  class Shutdown(val reason: String) extends Message

  trait ActorState

  class Active(val processedCount: Int) extends ActorState

  class Paused(val since: Long, val reason: String) extends ActorState

  class Stopped(val at: Long) extends ActorState

  trait Behaviour {
  def receive(message: Message, state: ActorState): (List[Message], ActorState)

  def onStart(): ActorState

  def onStop(state: ActorState): Unit
  }

  class EchoBehaviour extends Behaviour {
  def receive(message: Message, state: ActorState): (List[Message], ActorState) =
    message match {
      case req: Request =>
        val reply = new Response(req.id, 200, req.payload.mkString(","))
        val newState = state match {
          case a: Active => new Active(a.processedCount + 1)
          case other => other
        }
        (List(reply), newState)
      case _: Shutdown => (List.empty, new Stopped(System.currentTimeMillis()))
      case _ => (List.empty, state)
    }

  def onStart(): ActorState = new Active(0)

  def onStop(state: ActorState): Unit = {}
  }

  class Supervisor {
  private var actors: Map[String, Behaviour] = Map.empty
  private var states: Map[String, ActorState] = Map.empty

  def spawn(id: String, behaviour: Behaviour): Unit = {
    actors = actors + (id -> behaviour)
    states = states + (id -> behaviour.onStart())
  }

  def send(id: String, message: Message): List[Message] =
    actors.get(id).map { b =>
      val (replies, newState) = b.receive(message, states(id))
      states = states + (id -> newState)
      replies
    }.getOrElse(List.empty)

  def stop(id: String): Unit = actors.get(id).foreach { b => b.onStop(states(id)); actors = actors - id }
  }
  '''
end
