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
  The PRNG is currently the Mersenne Twister with standard initialisation values.
*/
alias RNG = Mt19937;
/// Ditto
RNG rng;

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

unittest {
  immutable double s0v0 = 1.0976270048640728305144875776022672653198242187500000;
  immutable double s0v1 = 1.1856892330538686408658577420283108949661254882812500;
  immutable double s0v2 = 1.4303787302762218658358506218064576387405395507812500;

  immutable double s1v0 = 0.8340439970684339066053780697984620928764343261718750;
  immutable double s1v1 = 1.9943696167306901312343825338757596909999847412109375;
  immutable double s1v2 = 1.4406489789114911292955412136507220566272735595703125;

  immutable double s42v0 = 0.7490802287936861869610538633423857390880584716796875;
  immutable double s42v1 = 1.5930859687722020989752991226851008832454681396484375;
  immutable double s42v2 = 1.9014286235676676195538448155275546014308929443359375;

  rng.seed(0);
  assert( uniform(0.0, 2.0, rng) == s0v0);
  assert( uniform(0.0, 2.0, rng) == s0v1);
  assert( uniform(0.0, 2.0, rng) == s0v2);

  rng.seed(1);
  assert( uniform(0.0, 2.0, rng) == s1v0);
  assert( uniform(0.0, 2.0, rng) == s1v1);
  assert( uniform(0.0, 2.0, rng) == s1v2);

  rng.seed(42);
  assert( uniform(0.0, 2.0, rng) == s42v0);
  assert( uniform(0.0, 2.0, rng) == s42v1);
  assert( uniform(0.0, 2.0, rng) == s42v2);

  // Fresh seeding should start from the top again.
  rng.seed(0);
  assert( uniform(0.0, 2.0, rng) == s0v0);
  assert( uniform(0.0, 2.0, rng) == s0v1);
  assert( uniform(0.0, 2.0, rng) == s0v2);

}

