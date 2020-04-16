use "debug"
use "collections/persistent"

actor Main
  new create(env: Env) =>
    env.out.print("Running example dataflow...")

    let input: Input[String] = input.create()

    input
      .flatMap[String]({(sentence) => sentence.split(" .,")})
      .map[String]({(word) => word.lower()})
      .reduce[Map[String, USize] val](
        {(x, acc) => acc.update(x, acc.get_or_else(x, 0) + 1)},
        Map[String, USize].create()
      )
      .subscribe(
        object is Observer[Map[String, USize] val]
          be on_receive(result: Map[String, USize] val, ts: Timestamp) =>
            for pair in result.pairs() do
              env.out.print("(" + pair._1 + ", " + pair._2.string() + ")")
            end

          be on_notify(ts: Timestamp) =>
            for t in ts.values() do
              env.out.print("Timestamp: " + t.string())
            end
        end
      )

    input.send("An elephant is an animal.")
    input.send("All work and no play makes Jack a dull boy.")
    // input.complete()

    env.out.print("Done...")
