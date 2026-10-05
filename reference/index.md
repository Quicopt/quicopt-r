# Package index

## Building a model

- [`model()`](https://quicopt.github.io/quicopt-r/reference/model.md) :
  Create an empty model
- [`num_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  [`int_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  [`bin_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  [`add_var()`](https://quicopt.github.io/quicopt-r/reference/num_var.md)
  : Declare decision variables
- [`set_start()`](https://quicopt.github.io/quicopt-r/reference/set_start.md)
  : Start the next search from a known solution
- [`minimize()`](https://quicopt.github.io/quicopt-r/reference/minimize.md)
  [`maximize()`](https://quicopt.github.io/quicopt-r/reference/minimize.md)
  : Set the objective
- [`add()`](https://quicopt.github.io/quicopt-r/reference/add.md) : Add
  constraints to a model
- [`expressions`](https://quicopt.github.io/quicopt-r/reference/expressions.md)
  : Expressions: arithmetic on variables
- [`holds()`](https://quicopt.github.io/quicopt-r/reference/holds.md) :
  A comparison as a 0/1 expression

## Uncertain data

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
  : Use observed data as a model's uncertainty
- [`distribution()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
  [`normal()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
  [`uniform()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
  [`exponential()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
  [`bernoulli()`](https://quicopt.github.io/quicopt-r/reference/distribution.md)
  : Distributions for random variables
- [`empirical()`](https://quicopt.github.io/quicopt-r/reference/empirical.md)
  : A random variable given by a sample
- [`expectation()`](https://quicopt.github.io/quicopt-r/reference/expectation.md)
  : The average over the scenarios
- [`cvar()`](https://quicopt.github.io/quicopt-r/reference/cvar.md) :
  The average over the worst scenarios
- [`prob()`](https://quicopt.github.io/quicopt-r/reference/prob.md) :
  The probability that a comparison holds
- [`variance()`](https://quicopt.github.io/quicopt-r/reference/variance.md)
  [`std_dev()`](https://quicopt.github.io/quicopt-r/reference/variance.md)
  : The variance and the standard deviation over the scenarios
- [`scenario_max()`](https://quicopt.github.io/quicopt-r/reference/scenario_max.md)
  [`scenario_min()`](https://quicopt.github.io/quicopt-r/reference/scenario_max.md)
  [`scenario_quantile()`](https://quicopt.github.io/quicopt-r/reference/scenario_max.md)
  : The largest, the smallest and a quantile over the scenarios
- [`is_random()`](https://quicopt.github.io/quicopt-r/reference/is_random.md)
  : Does an expression vary across scenarios?

## Orders and assignments

- [`perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md)
  [`add_perm_var()`](https://quicopt.github.io/quicopt-r/reference/perm_var.md)
  : Declare an order as a decision
- [`item_at()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)
  [`slot_of()`](https://quicopt.github.io/quicopt-r/reference/item_at.md)
  : The item in a slot, and the slot of an item
- [`precede()`](https://quicopt.github.io/quicopt-r/reference/precede.md)
  : Require one item to come before another
- [`lookup_table()`](https://quicopt.github.io/quicopt-r/reference/lookup_table.md)
  [`` `[`( ``*`<quicopt_table>`*`)`](https://quicopt.github.io/quicopt-r/reference/lookup_table.md)
  : A table of data indexed by decisions

## Solving and checking a solution

- [`solve_model()`](https://quicopt.github.io/quicopt-r/reference/solve_model.md)
  [`solve(`*`<quicopt_model>`*`)`](https://quicopt.github.io/quicopt-r/reference/solve_model.md)
  : Solve a model
- [`submit()`](https://quicopt.github.io/quicopt-r/reference/submit.md)
  : Solve a model without waiting
- [`job_status()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
  [`job_result()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
  [`job_log()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
  [`job_delete()`](https://quicopt.github.io/quicopt-r/reference/job_status.md)
  : Follow up a submitted job
- [`evaluate()`](https://quicopt.github.io/quicopt-r/reference/evaluate.md)
  : Compute a quantity at a given solution
- [`resample()`](https://quicopt.github.io/quicopt-r/reference/resample.md)
  : Check a solution on new scenarios
- [`DEFAULT_BASE_URL`](https://quicopt.github.io/quicopt-r/reference/DEFAULT_BASE_URL.md)
  : The address of the public Quicopt service

## Building a program by hand

- [`program()`](https://quicopt.github.io/quicopt-r/reference/program.md)
  : A model as plain data
- [`CONTINUOUS`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)
  [`INTEGER`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)
  [`BINARY`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)
  [`var_decl()`](https://quicopt.github.io/quicopt-r/reference/var_decl.md)
  : A decision variable, for building a program by hand
- [`index_set()`](https://quicopt.github.io/quicopt-r/reference/index_set.md)
  : An index set, for building a program by hand
- [`constraint()`](https://quicopt.github.io/quicopt-r/reference/constraint.md)
  : A constraint, for building a program by hand
- [`zero()`](https://quicopt.github.io/quicopt-r/reference/consets.md)
  [`nonneg()`](https://quicopt.github.io/quicopt-r/reference/consets.md)
  [`indicator()`](https://quicopt.github.io/quicopt-r/reference/consets.md)
  : Constraint sets, for building a program by hand
- [`parametric()`](https://quicopt.github.io/quicopt-r/reference/parametric.md)
  : A random variable with a distribution, for building a program by
  hand
- [`permutation_decl()`](https://quicopt.github.io/quicopt-r/reference/permutation_decl.md)
  : A permutation, for building a program by hand
- [`ir_const()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_param()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_var()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_apply()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_reduce()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_source_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_struct_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_table_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  [`ir_set_ref()`](https://quicopt.github.io/quicopt-r/reference/ir.md)
  : Expression nodes, for building a program by hand
- [`wire`](https://quicopt.github.io/quicopt-r/reference/wire.md) : The
  bytes sent to the service
- [`encode()`](https://quicopt.github.io/quicopt-r/reference/encode.md)
  : Encode a model as the bytes the service reads
- [`encode_params()`](https://quicopt.github.io/quicopt-r/reference/encode_params.md)
  : Encode parameter tables on their own
- [`as_program()`](https://quicopt.github.io/quicopt-r/reference/as_program.md)
  : Convert a model to a program
