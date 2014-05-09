module dlbc.random;

import dlbc.logging;
import dlbc.parallel;

import std.random;

@("param") int seed;

Mt19937 rng;

void initRNG() {
  writeLogRI("Initializing random number generator of type '%s' with seed %d plus MPI rank.", typeof(rng).stringof, seed);
  rng.seed(seed + M.rank);
}

