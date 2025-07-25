## Synopsis

This project is part of the [Iris Masterplan](https://julesjacobs.com/slides/iris-masterplan.pdf).
It aims at verifying OCaml 5 programs, including [lock-free data structures](lib/zoo_saturn) from [Saturn](https://github.com/ocaml-multicore/saturn), a [lock-free multi-word compare-and-set algorithm](lib/zoo_kcas) from [Kcas](https://github.com/ocaml-multicore/kcas) and a [work-stealing scheduler](lib/zoo_parabs) based on [Domainslib](https://github.com/ocaml-multicore/domainslib).

## Building (Coq proofs only)

First, you need to install [`opam`](https://opam.ocaml.org/) (>= 2.0).

To make sure it is up-to-date, run:

```
opam update --all --repositories
```

Then, create a new local `opam` switch and install dependencies with:

```
opam switch create . --empty --repos default,coq-released=https://coq.inria.fr/opam/released,iris-dev=git+https://gitlab.mpi-sws.org/iris/opam.git --yes
opam install ./coq-*.opam --deps-only --yes
eval $(opam env --switch=. --set-switch)
```

Finally, to compile Coq proofs, run:

```
make -j
```

## Building (OCaml libraries and Coq proofs)

First, you need to install [`opam`](https://opam.ocaml.org/) (>= 2.0).

To make sure it is up-to-date, run:

```
opam update --all --repositories
```

Then, you need to install [this custom version of the OCaml compiler](https://github.com/clef-men/ocaml/tree/generative_constructors) featuring atomic record fields, atomic arrays and generative constructors.
Hopefully, it should be merged into the OCaml compiler one day.

The following commands take care of this:

```
opam switch create . --empty --repos default,coq-released=https://coq.inria.fr/opam/released,iris-dev=git+https://gitlab.mpi-sws.org/iris/opam.git --yes
eval $(opam env --switch=. --set-switch)
opam pin add ocaml-variants git+https://github.com/clef-men/ocaml#generative_constructors --yes
```

Then, install dependencies including [`ocaml2zoo`](https://github.com/clef-men/ocaml2zoo) with:

```
opam pin add ocaml2zoo git+https://github.com/clef-men/ocaml2zoo#main --yes
opam install . --deps-only --yes
```

To compile OCaml libraries (see `lib/`), run:

```
make lib
```

To translate OCaml libraries into [Zoo](https://github.com/clef-men/zoo) (Coq files are generated in `theories/`), run:

```
make ocaml2zoo
```

Finally, to compile Coq proofs, run:

```
make -j
```

## Installation

Zoo is not available on `opam` yet, but you can already use it in your Coq developments by adding the following `opam` dependency:

```
pin-depends: [
  ["coq-zoo.dev" "git+https://github.com/clef-men/zoo.git#main"]
]
depends: [
  "coq-zoo"
]
```

To also install the standard library, add:

```
pin-depends: [
  ["coq-zoo.dev" "git+https://github.com/clef-men/zoo.git#main"]
  ["coq-zoo-std.dev" "git+https://github.com/clef-men/zoo.git#main"]
]
depends: [
  "coq-zoo-std"
]
```

See also [this example](https://github.com/clef-men/zoo-demo).
