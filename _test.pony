use "ponytest"
use "debug"
use "collections/persistent"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    test(_TestInput)
    test(_TestMap)
    test(_TestFlatMap)
//     test(_TestReduce)

actor _Inspect[A: Stringable val] is Observer[A]
  var _all: Vec[A] = _all.create()
  var _fn: {(Vec[A]): None}

  new create(fn: {(Vec[A]): None} iso) =>
    _fn = consume fn

  be on_receive(x: A, t: Timestamp) =>
    _all = _all.push(x)

  be on_notify(t: Timestamp) =>
    None

  be on_complete() =>
    _fn(_all)

class iso _TestInput is UnitTest
  fun name(): String => "input"

  fun apply(h: TestHelper) =>
    h.long_test(1_000_000)

    let input: Input[String] =
      input.create()

    input.subscribe(
      _Inspect[String]({(xs) =>
        h.assert_true(xs.contains("foo"))
        h.assert_true(xs.contains("bar"))
        h.complete(true)
      })
    )

    input.send("foo")
    input.send("bar")
    input.complete()

class iso _TestMap is UnitTest
  fun name(): String => "map"

  fun apply(h: TestHelper) =>
    h.long_test(1_000_000)

    let input: Input[String] =
      input.create()

    input
      .map[String]({(x) => x.lower()})
      .subscribe(
        _Inspect[String]({(xs) =>
          try
            h.assert_eq[String](xs(0)?, "foo")
            h.assert_eq[String](xs(1)?, "bar")
            h.complete(true)
          else
            h.complete(false)
          end
        })
      )

    input.send("FOO")
    input.send("BAR")
    input.complete()

class iso _TestFlatMap is UnitTest
  fun name(): String => "flatMap"

  fun apply(h: TestHelper) =>
    h.long_test(1_000_000)

    let input: Input[String] =
      input.create()

    input
      .flatMap[String]({(x) => x.split(" ")})
      .subscribe(_Inspect[String]({(xs) =>
        try
          h.assert_eq[String](xs(0)?, "An")
          h.assert_eq[String](xs(1)?, "elephant")
          h.assert_eq[String](xs(2)?, "is")
          h.assert_eq[String](xs(3)?, "an")
          h.assert_eq[String](xs(4)?, "animal")
          h.complete(true)
        else
          h.complete(false)
        end
      }))

    input.send("An elephant is an animal")
    input.complete()
