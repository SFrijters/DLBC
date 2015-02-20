// Written in the D programming language.

/**
   Helper functions for random number generation.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.random;

import dlbc.logging;
import dlbc.parallel;

public import std.random;

/**
  The seed for the PRNG to be used. Depending on the initialisation this value
  may be modified according to the rank of the process to avoid the creation
  of identical domains.
*/
@("param") int seed;

/**
  The PRNG is currently the Mersenne Twister with standard initialisation values.
*/
Mt19937 rng;

/**
   Initialises the PRNG on each process.
*/
void initRNG() {
  writeLogRI("Initializing random number generator of type '%s' with seed %d plus MPI rank.", typeof(rng).stringof, seed);
  // Each process gets a different seed.
  rng.seed(seed + M.rank);
}

