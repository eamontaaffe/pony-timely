actor Main
  new create(env: Env) =>
    env.out.print("Running example dataflow...")

    Dataflow({(scope) =>
      let input: Input[String] = input.create()

      scope
        .input_from(input)
        .map[Array[String]]({(scentence) => x.split(" .,")})
        .flatten()
        .map[(String, USize)]({(word) => (word, 1)})
        .probe({(result) => env.out.print(result.string())})

      input.send("An elephant is an animal.")
      input.send("All work and no play makes Jack a dull boy.")
      input.complete()
    })
