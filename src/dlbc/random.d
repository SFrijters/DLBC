module dlbc.random;

import dlbc.logging;
import dlbc.parallel;
import dlbc.parameters;

import std.random;

Mt19937 rng;

void initRNG() {
  writeLogRI("Initializing random number generator of type '%s' with seed %d plus MPI rank.", typeof(rng).stringof, P.seed);
  rng.seed(P.seed + M.rank);
}

