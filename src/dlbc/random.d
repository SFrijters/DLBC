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
   If set to true, each rank's RNG will be seeded with $(D seed + M.rank),
   otherwise, all ranks will be seeded with only $(D seed).
*/
@("param") bool shiftSeedByRank = true;

/**
  The PRNG is currently the Mersenne Twister with standard initialisation values.
*/
Mt19937 rng;

/**
   Initialises the PRNG on each process.
*/
void initRNG() {
  // Each process gets a different seed.
  if ( shiftSeedByRank ) {
    writeLogRI("Initializing random number generator of type '%s' with seed %d plus MPI rank.", typeof(rng).stringof, seed);
    rng.seed(seed + M.rank);
  }
  else {
    writeLogRI("Initializing random number generator of type '%s' with seed %d.", typeof(rng).stringof, seed);
    rng.seed(seed);
  }
}

