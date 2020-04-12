use "collections/persistent"

type Timestamp is Vec[USize]
type Message[A] is A

trait VertexNotify[A: Any #share, B: Any #share]
  fun on_receive(vertex: Vertex[A, B], m: Message[A], t: Timestamp): None
  fun on_notify(vertex: Vertex[A, B], t: Timestamp): None

trait Observer[A: Any #share]
  fun tag on_receive(m: Message[A], t: Timestamp): None
  fun tag on_notify(t: Timestamp): None

trait Observable[A: Any #share]
  fun tag subscribe(o: Observer[A] tag): None

actor Vertex[A: Any #share, B: Any #share] is (Observer[A] & Observable[B])
  """
  Vertex implemented using the Notifier pattern:
  https://patterns.ponylang.io/code-sharing/notifier.html
  """
  let _subscribers: Array[Observer[A] tag] = _subscribers.create()
  let _notify: VertexNotify[A, B]

  new create(notify: VertexNotify[A, B] iso) =>
    _notify = consume notify

  be subscribe(subscriber: Observer[A] tag) =>
    _subscribers.push(subscriber)

  be on_receive(m: Message[A], t: Timestamp) =>
    _notify.on_receive(this, m, t)

  be on_notify(t: Timestamp) =>
    _notify.on_notify(this, t)

  fun _send_at(message: Message[A], timestamp: Timestamp): None =>
    for s in _subscribers.values() do
      s.on_receive(this, message, timestamp)
    end

  fun _notify_at(timestamp: Timestamp): None =>
    for s in _subscribers.values() do
      s.on_notify(timestamp)
    end

actor Input[A: Any #share] is Observable[A]
  var _epoch: USize = 0
  let _subscribers: Array[Observer[A] tag] = _subscribers.create()

  be subscribe(subscriber: Observer[A] tag) =>
    _subscribers.push(subscriber)

  be send(message: Message[A]) =>
    let timestamp: Timestamp = [ _epoch = _epoch + 1 ]
    for s in _subscribers.values() do
      s.on_recieve(message, timestamp)
      s.on_notify(timestamp)
    end
