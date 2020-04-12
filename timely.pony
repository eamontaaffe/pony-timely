trait Channel[A]
  let _consumers: Array[Observer[A] tag] = _consumers.create()

  fun subscribe(consumer: Observer[A] tag): None =>
    _consumers.push(consumer)

  fun _send(message: Message[A], timestamp: Timestamp): None =>
    for c in _consumers.values() do
      c.on_recieve(this, message, timestamp)
    end

  fun _notify(timestamp): None =>
    for c in _consumers.values() do
      c.on_notify(timestamp)
    end


trait Operator
  fun tag _send_by[A](c: Channel[A], m: Message[A], t: Timestamp): None =>
    // TODO: Implement _send_by
    None

  fun tag _notify_at(t: Timestamp): None =>
    // TODO: Implement _notify_at
    None

  fun tag on_receive[A](c: Channel[A], m: Message[A], t: Timestamp): None
  fun tag on_notify(t: Timestamp): None


actor DistinctCount is Operator


actor IngressOperator is Operator
  """
  Ingress vertices add a new index:

  Input timestamp: (c1,...,ck)
  Output timestamp: (c1,...,ck,0)
  """

  be on_receive(message: Message[A], timestamp: Timestamp) =>
    _send_by(message, timestamp.push(0))

  be on_notify(timestamp: Timestamp) =>
    _notify_at(timestamp.push(0))


actor EgressOperator[A] is (Observer[A] & Observable[A])
  """
  Egress vertices removes the last index:

  Input timestamp: (c1,...,ck,ck+1)
  Output timestamp: (c1,...,ck)
  """

  be on_receive(message: Message[A], timestamp: Timestamp) =>
    _send_by(message, timestamp.pop())

  be on_notify(timestamp: Timestamp) =>
    _notify_at(timestamp.pop())


actor FeedbackOperator[A] is (Observer[A] & Observable[A])
  """
  Feedback vertices increments the last index:

  Input timestamp: (c1,...,ck)
  Ouput timestamp: (c1,...,inc(ck))
  """

  be on_receive(message: Message[A], timestamp: Timestamp) =>
    _send_by(
      message,
      timestamp.update(timestamp.size() - 1, {(x) => x.add(1)})
    )

  be on_notify(timestamp: Timestamp) =>
    _notify_at(
      message,
      timestamp.update(timestamp.size() - 1, {(x) => x.add(1)})
    )
