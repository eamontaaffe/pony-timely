use "collections/persistent"
use "debug"

type Timestamp is Vec[USize]
type Message[A] is A

trait Observer[A: Any #share]
  fun tag on_receive(m: Message[A], t: Timestamp): None
  fun tag on_notify(t: Timestamp): None

trait Observable[X: Any #share]
  fun tag subscribe(o: Observer[X] tag): None

  fun tag map[Y: Any #share](fn: {(X): Y} iso): Observable[Y] tag =>
    let notify = MapNotify[X, Y].create(consume fn)
    let wrapper = VertexWrapper[X, Y](consume notify)
    subscribe(wrapper.inner)
    wrapper.inner

  fun tag flatMap[Y: Any #share](fn: {(X): Array[Y]} iso): Observable[Y] tag =>
    let notify = FlatMapNotify[X, Y].create(consume fn)
    let wrapper = VertexWrapper[X, Y](consume notify)
    subscribe(wrapper.inner)
    wrapper.inner

class VertexWrapper[A: Any #share, B: Any #share]
  """
  Wrapper class required as a workaround for:
  https://github.com/ponylang/ponyc/issues/1875
  """

  let inner: (Observer[A] tag & Observable[B] tag)

  new create(notify: VertexNotify[A, B] iso) =>
    inner = Vertex[A, B].create(consume notify)


trait VertexNotify[A: Any #share, B: Any #share]
  fun on_receive(vertex: Vertex[A, B], m: Message[A], t: Timestamp): None
  fun on_notify(vertex: Vertex[A, B], t: Timestamp): None


class MapNotify[A: Any #share, B: Any #share] is VertexNotify[A, B]
  let _fn: {(A): B}

  new iso create(fn: {(A): B} iso) =>
    _fn = consume fn

  fun on_receive(vertex: Vertex[A, B], m: Message[A], t: Timestamp): None =>
    vertex.send_at(_fn(m), t)

  fun on_notify(vertex: Vertex[A, B], t: Timestamp): None =>
    vertex.notify_at(t)
    None

class FlatMapNotify[A: Any #share, B: Any #share] is VertexNotify[A, B]
  let _fn: {(A): Array[B]}

  new iso create(fn: {(A): Array[B]} iso) =>
    _fn = consume fn

  fun on_receive(vertex: Vertex[A, B], m: Message[A], t: Timestamp): None =>
    for m' in _fn(m).values() do
      vertex.send_at(m', t)
    end

  fun on_notify(vertex: Vertex[A, B], t: Timestamp): None =>
    vertex.notify_at(t)
    None

actor Vertex[A: Any #share, B: Any #share] is (Observer[A] & Observable[B])
  """
  Vertex implemented using the Notifier pattern:
  https://patterns.ponylang.io/code-sharing/notifier.html
  """
  let _subscribers: Array[Observer[B] tag] = _subscribers.create()
  let _notify: VertexNotify[A, B]

  new create(notify: VertexNotify[A, B] iso) =>
    _notify = consume notify

  be subscribe(subscriber: Observer[B] tag) =>
    _subscribers.push(subscriber)

  be on_receive(m: Message[A], t: Timestamp) =>
    _notify.on_receive(this, m, t)

  be on_notify(t: Timestamp) =>
    _notify.on_notify(this, t)

  be send_at(message: Message[B], timestamp: Timestamp) =>
    for s in _subscribers.values() do
      s.on_receive(message, timestamp)
    end

  be notify_at(timestamp: Timestamp) =>
    for s in _subscribers.values() do
      s.on_notify(timestamp)
    end

actor Input[A: Any #share] is Observable[A]
  var _epoch: USize = 0
  let _subscribers: Array[Observer[A] tag] = _subscribers.create()

  be subscribe(subscriber: Observer[A] tag) =>
    _subscribers.push(subscriber)

  be send(message: Message[A]) =>
    let timestamp: Timestamp = Vec[USize].push(_epoch = _epoch + 1)
    for s in _subscribers.values() do
      s.on_receive(message, timestamp)
      s.on_notify(timestamp)
    end
