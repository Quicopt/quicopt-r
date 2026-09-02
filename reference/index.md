# Package index

## Authoring a model

- [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md) :
  Create an empty optimization model
- [`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  [`int_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  [`bin_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  [`add_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  : Declare decision variables
- [`minimize()`](https://quicopt.github.io/quicopt-r/reference/minimize.md)
  [`maximize()`](https://quicopt.github.io/quicopt-r/reference/minimize.md)
  : State what the model optimizes
- [`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) : Add
  constraints to a model
- [`expressions`](https://quicopt.github.io/quicopt-r/reference/expressions.md)
  : quicopt expressions — model arithmetic in plain R

## Uncertainty

- [`stochastic`](https://quicopt.github.io/quicopt-r/reference/stochastic.md)
  : Optimization under uncertainty

- [`rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
  [`add_rand_var()`](https://quicopt.github.io/quicopt-r/reference/rand_var.md)
  : Declare a random variable

- [`set_distribution()`](https://quicopt.github.io/quicopt-r/reference/set_distribution.md)
  : Give a random variable its distribution

- [`set_scenarios()`](https://quicopt.github.io/quicopt-r/reference/set_scenarios.md)
  : Set how many scenarios are drawn, and from which seed

- [`set_empirical()`](https://quicopt.github.io/quicopt-r/reference/set_empirical.md)
  : Turn observed history into a model's uncertainty

- [`distribution()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
  [`normal()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
  : Distributions for random variables

- [`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
  : A random variable given as a fixed scenario column

- [`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md)
  : The expected value over the scenarios

- [`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md) :

  The conditional value at risk at level `alpha`

- [`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) :
  The probability that a comparison holds

## Solving

- [`solve_model()`](https://quicopt.github.io/quicopt-r/reference/solve_model.md)
  [`solve(`*`<quicopt_model>`*`)`](https://quicopt.github.io/quicopt-r/reference/solve_model.md)
  : Solve a model with the Quicopt service
- [`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
  : Submit a model for asynchronous solving
- [`job_status()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
  [`job_result()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
  [`job_log()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
  [`job_delete()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
  : Poll a submitted job
- [`DEFAULT_BASE_URL`](https://quicopt.github.io/quicopt-r/reference/DEFAULT_BASE_URL.md)
  : The public Quicopt endpoint

## The program and its bytes

- [`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
  : A complete optimization model as plain data
- [`CONTINUOUS`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)
  [`INTEGER`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)
  [`BINARY`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)
  [`var_decl()`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)
  : A variable declaration
- [`index_set()`](https://quicopt.github.io/quicopt-r/reference/index_set.md)
  : A named index set with concrete elements
- [`constraint()`](https://quicopt.github.io/quicopt-r/reference/constraint.md)
  : A constraint row
- [`zero()`](https://quicopt.github.io/quicopt-r/reference/consets.md)
  [`nonneg()`](https://quicopt.github.io/quicopt-r/reference/consets.md)
  [`indicator()`](https://quicopt.github.io/quicopt-r/reference/consets.md)
  : Constraint sets
- [`parametric()`](https://quicopt.github.io/quicopt-r/reference/parametric.md)
  : A random variable drawn from a distribution
- [`ir_const()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_param()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_var()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_apply()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_reduce()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_source_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_set_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  : quicopt IR — a model as plain data
- [`wire`](https://quicopt.github.io/quicopt-r/reference/wire.md) :
  quicopt wire — a program's bytes
- [`encode()`](https://quicopt.github.io/quicopt-r/reference/encode.md)
  : Encode a program to the bytes the service reads
- [`encode_params()`](https://quicopt.github.io/quicopt-r/reference/encode_params.md)
  : Encode parameter tables alone, for rebinding data
- [`as_program()`](https://quicopt.github.io/quicopt-r/reference/as_program.md)
  : Lower a model to a program
