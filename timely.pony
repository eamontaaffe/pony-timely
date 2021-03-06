use "collections/persistent"
use "debug"

type Timestamp is Vec[USize]
type Message[A] is A

trait Observer[A: Any #share]
  fun tag on_receive(m: Message[A], t: Timestamp): None
  fun tag on_notify(t: Timestamp): None
  fun tag on_complete(): None

trait Observable[X: Any #share]
  fun tag subscribe(o: Observer[X] tag): None

  fun tag map[Y: Any #share](fn: {(X): Y} iso): Observable[Y] tag =>
    _applyNotify[Y](MapNotify[X, Y].create(consume fn))

  fun tag flatMap[Y: Any #share](fn: {(X): Array[Y]} iso): Observable[Y] tag =>
    _applyNotify[Y](FlatMapNotify[X, Y].create(consume fn))

  fun tag reduce[Y: Any #share](fn: {(X, Y): Y} iso, acc: Y): Observable[Y] tag =>
    _applyNotify[Y](ReduceNotify[X, Y].create(consume fn, acc))

//   fun tag partition(count: USize, selector: {(Message[A]): USize}): Array[Observable[X] tag] =>
//     """
//     Partition returns multiple observables with each observable contains only
//     the elements selected for it by the `selector` function.
//     """
//     // TODO: Implement partition
//
//   fun tag concat(Observable[X] tag): Observable[X] tag =>
//     """
//     Concat is the opposite of partition. It joins another observable of the
//     same type to create a union of outputs.
//     """
//     // TODO Implement concat

  fun tag _applyNotify[Y: Any #share](notify: VertexNotify[X, Y] iso): Observable[Y] tag =>
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
  fun on_complete(vertex: Vertex[A, B]): None

class MapNotify[A: Any #share, B: Any #share] is VertexNotify[A, B]
  let _fn: {(A): B}

  new iso create(fn: {(A): B} iso) =>
    _fn = consume fn

  fun on_receive(vertex: Vertex[A, B], m: Message[A], t: Timestamp): None =>
    vertex.send_at(_fn(m), t)

  fun on_notify(vertex: Vertex[A, B], t: Timestamp): None =>
    vertex.notify_at(t)

  fun on_complete(vertex: Vertex[A, B]): None =>
    vertex.complete_at()

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

  fun on_complete(vertex: Vertex[A, B]): None =>
    vertex.complete_at()

class ReduceNotify[A: Any #share, B: Any #share] is VertexNotify[A, B]
  let _fn: {(A, B): B}
  let _acc: B

  new iso create(fn: {(A, B): B} iso, acc: B) =>
    _fn = consume fn
    _acc = consume acc

  fun on_receive(vertex: Vertex[A, B], m: Message[A], t: Timestamp): None =>
    // TODO: Implement ReduceNotify
    None

  fun on_notify(vertex: Vertex[A, B], t: Timestamp): None =>
    vertex.notify_at(t)

  fun on_complete(vertex: Vertex[A, B]): None =>
    vertex.complete_at()

actor Vertex[A: Any #share, B: Any #share] is (Observer[A] & Observable[B])
  """
  Vertex implemented using the Notifier pattern:
  https://patterns.ponylang.io/code-sharing/notifier.html

  TODO: Use different word than Notify, it is already used by timely pattern
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

  be on_complete() =>
    _notify.on_complete(this)

  be send_at(message: Message[B], timestamp: Timestamp) =>
    for s in _subscribers.values() do
      s.on_receive(message, timestamp)
    end

  be notify_at(timestamp: Timestamp) =>
    for s in _subscribers.values() do
      s.on_notify(timestamp)
    end

  be complete_at() =>
    for s in _subscribers.values() do
      s.on_complete()
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
    end

  be complete() =>
    for s in _subscribers.values() do
      s.on_complete()
    end
