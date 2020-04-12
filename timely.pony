class Observable[A]
  let _consumers: Array[Observer[A] tag] = _consumers.create()

  fun apply(consumer: Observer[A] tag): None =>
    _consumers.push(consumer)

  fun send(message: Message[A], timestamp: Timestamp): None =>
    for c in _consumers.values() do
      c.on_recieve(this, message, timestamp)
    end

  fun notify(timestamp): None =>
    for c in _consumers.values() do
      c.on_notify(timestamp)
    end


trait Observer[A]
  fun tag on_receive(m: Message[A], t: Timestamp): None
  fun tag on_notify(t: Timestamp): None


trait Vertex[A, B] is (Observer[A] & Observable[B])


actor IngressVertex[A] is Vertex[A, A]
  """
  Ingress vertices add a new index:

  Input timestamp: (c1,...,ck)
  Output timestamp: (c1,...,ck,0)
  """

  fun tag on_recieve(m: Message[A], t: Timestamp): None =>
    observable.notify(m, t.push(0))

  fun tag on_notify(t: Timestamp): None =>
    observable.notify(t.push(0))


actor EgressVertex[A] is Vertex[A, A]
  """
  Egress vertices removes the last index:

  Input timestamp: (c1,...,ck,ck+1)
  Output timestamp: (c1,...,ck)
  """

  fun tag on_recieve(m: Message[A], t: Timestamp): None =>
    observable.notify(m, t.pop())

  fun tag on_notify(t: Timestamp): None =>
    observable.notify(t.pop())


actor FeedbackVertex[A] is Vertex[A, A]
  """
  Feedback vertices increments the last index:

  Input timestamp: (c1,...,ck)
  Ouput timestamp: (c1,...,inc(ck))
  """

  fun tag on_recieve(m: Message[A], t: Timestamp): None =>
    observable.notify(m, t.push(0))

  fun tag on_notify(t: Timestamp): None =>
    observable.notify(t.push(0))
