use "debug"

actor Main
  new create(env: Env) =>
    env.out.print("Running example dataflow...")

    let input: Input[String] = input.create()

    input
      .flatMap[String]({(scentence) => scentence.split(" .,")})
      .map[(String, USize)]({(word) => (word, 1)})
      .subscribe(
        object is Observer[(String, USize)]
          be on_receive(result: (String, USize), ts: Timestamp) =>
            env.out.print("(" + result._1 + ", " + result._2.string() + ")")

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
