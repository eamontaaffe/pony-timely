use "debug"
use "collections/persistent"
use "itertools"
use c = "collections"

actor Main
  """
  Using a similar example to here: 
  https://timelydataflow.github.io/timely-dataflow/chapter_1/chapter_1_1.html
  """

  new create(env: Env) =>
    env.out.print("Running example dataflow...")

    let input: Input[USize] = input.create()

    input
      .map[USize]({(x) => x})
      .map[USize]({(x) => x})
      .map[USize]({(x) => x})
      .map[USize]({(x) => x})
      .subscribe(
        object is Observer[USize]
          be on_receive(x: USize, ts: Timestamp) =>
            let limit = x.f64().sqrt().usize()
            if ((x > 1) and Iter[USize](c.Range(2, limit + 1)).all({(i) => (x % i) > 0})) then
              env.out.print(x.string() + " is a prime!")
            end

          be on_notify(ts: Timestamp) => None
        end
      )

    for i in c.Range(0, 10_000_000) do
      input.send(i)
    end

    // input.complete()

    env.out.print("Done...")
