// Written in the D programming language.

/**
   Helper functions to validate Laplace's law for surface tension between fluid components.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.lb.laplace;

import dlbc.lattice;
import dlbc.parallel;
import dlbc.logging;
import dlbc.lb.density;
import dlbc.lb.force;
import dlbc.lb.lb;
import dlbc.lb.init;
import dlbc.lb.mask: isFluid;
import dlbc.range;

import std.conv: to;
import std.stdio;

/**
   When to start checking relative accuracy of surface tension calculations.
*/
@("param") int startCheck = -1;
/**
   The iterations end when $(D sigma / previousSigma - 1) is smaller than this,
   if its value is not NaN and is larger than zero.
*/
@("param") double relAccuracy;

/**
   Keep sigma in memory for convergence criteria.
*/
private double previousSigma;
/**
   Append to file or overwrite.
*/
private bool appendToFile = false;
/**
   Prefix for output files.
*/
private immutable string fileNamePrefix = "laplace";

/**
   Calculate Laplace pressure and write it to screen.

   Params:
     L = lattice
     t = current time step
*/
void dumpLaplace(T)(ref T L, in uint t) if ( isLattice!T ) {
  if ( ! enableShanChen || components != 2 ) {
    writeLogRW("Laplace pressure will not be calculated when enableShanChen != true, or components != 2.");
    return;
  }

  import std.algorithm: any, sum;
  import std.math;
  alias conn = L.lbconn;
  enum volumeAverage = 1;

  if ( any(initOffset) ||
       ( fluidInit[0] != FluidInit.EqDistSphere && fluidInit[0] != FluidInit.EqDistSphereFrac ) ||
       ( fluidInit[1] != FluidInit.EqDistSphere && fluidInit[1] != FluidInit.EqDistSphereFrac ) ) {
    writeLogRW("Laplace pressure calculation assumes the presence of a centred sphere!");
  }

  ptrdiff_t[conn.d] offsetIn;
  ptrdiff_t[conn.d] offsetOut;
  foreach(immutable vd; Iota!(0, conn.d) ) {
    offsetIn[vd] = to!int(L.gn[vd] * 0.5);
    offsetOut[vd] = volumeAverage;
  }

  auto inDen = L.volumeAveragedDensity(offsetIn, volumeAverage);
  auto outDen = L.volumeAveragedDensity(offsetOut, volumeAverage);

  // At t == 0, the average density of the block should be the same as the init density.
  assert(t != 0 || approxEqual(inDen[0], fluidDensities[0][0]));
  assert(t != 0 || approxEqual(inDen[1], fluidDensities[1][0]));
  assert(t != 0 || approxEqual(outDen[0], fluidDensities[0][1]));
  assert(t != 0 || approxEqual(outDen[1], fluidDensities[1][1]));

  auto inPres = pressure!conn(inDen);
  auto outPres = pressure!conn(outDen);

  double[] gMass;
  gMass.length = L.fluids.length;
  foreach(immutable f, ref field; L.fluids) {
    gMass[f] = field.globalTotalMass(L.mask);
  }

  double effMass = gMass[0] - ( L.gsize * outDen[0]);

  // Laplace law has different prefactor depending on dimensions.
  static if ( T.lbconn.d == 3 ) {
    double measuredR = pow(effMass / ( 4.0 / 3.0 * PI * ( inDen[0] - outDen[0] ) ), 1.0/3.0);
    double sigma = measuredR * ( inPres - outPres ) / 2.0;
  }
  else static if ( T.lbconn.d == 2 ) {
    double measuredR = pow(effMass / ( PI * ( inDen[0] - outDen[0] ) ), 1.0/2.0);
    double sigma = measuredR * ( inPres - outPres );
  }
  else static if ( T.lbconn.d == 1 ) {
    double measuredR = effMass / ( inDen[0] - outDen[0] );
    double sigma = measuredR * ( inPres - outPres );
  }
  else {
    static assert(0);
  }

  // At t == 0, the calculated surface tension should be zero.
  assert(t != 0 || approxEqual(sigma, 0.0));

  // Deformation calculation.
  double D;
  static if ( T.lbconn.d == 2 ) {
    import std.algorithm: min, max;
    double cutoff = 0.35;
    double Rx = 0.0;
    double Ry = 0.0;
    double mass = 0.0;

    foreach(immutable p, pop; L.fluids[0]) {
      if ( isFluid(L.mask[p]) ) {
        immutable den = L.density[0][p];
        if ( den > cutoff ) {
          ptrdiff_t[conn.d] gn;
          foreach(immutable vd; Iota!(0, conn.d) ) {
            gn[vd] = p[vd] + M.c[vd] * L.fluids[0].n[vd] - L.fluids[0].haloSize;
          }
          mass += den;
          Rx += den*gn[0];
          Ry += den*gn[1];
        }
      }
    }
    double globalRx, globalRy, globalMass;
    MPI_Allreduce(&Rx, &globalRx, 1, MPI_DOUBLE, MPI_SUM, M.comm);
    MPI_Allreduce(&Ry, &globalRy, 1, MPI_DOUBLE, MPI_SUM, M.comm);
    MPI_Allreduce(&mass, &globalMass, 1, MPI_DOUBLE, MPI_SUM, M.comm);

    globalRx /= globalMass;
    globalRy /= globalMass;

    writeLogRD("globalRx = %e, globalRy = %e, globalMass = %e", globalRx, globalRy, globalMass);

    // Use CoM as offset

    double dx = globalRx;
    double dy = globalRy;

    double Ixx = 0.0;
    double Ixy = 0.0;
    double Iyy = 0.0;
    foreach(immutable p, pop; L.fluids[0]) {
      if ( isFluid(L.mask[p]) ) {
        ptrdiff_t[conn.d] gn;
        immutable den = L.density[0][p];
        if ( den > cutoff ) {
	  foreach(immutable vd; Iota!(0, conn.d) ) {
	    gn[vd] = p[vd] + M.c[vd] * L.fluids[0].n[vd] - L.fluids[0].haloSize;
	  }
	  double x = gn[0] - dx;
	  double y = gn[1] - dy;
          Ixx += den*(y*y);
          Ixy += den*(x*y);
          Iyy += den*(x*x);
        }
      }
    }

    double globalIxx, globalIxy, globalIyy;
    MPI_Allreduce(&Ixx, &globalIxx, 1, MPI_DOUBLE, MPI_SUM, M.comm);
    MPI_Allreduce(&Ixy, &globalIxy, 1, MPI_DOUBLE, MPI_SUM, M.comm);
    MPI_Allreduce(&Iyy, &globalIyy, 1, MPI_DOUBLE, MPI_SUM, M.comm);
    writeLogRD("globalIxx = %e, globalIxy = %e, globalIyy = %e", globalIxx, globalIxy, globalIyy);

    immutable T = globalIxx + globalIyy;
    immutable det = globalIxx * globalIyy - globalIxy * globalIxy;
    immutable ev1 = 0.5*T + sqrt(0.25*T*T - det);
    immutable ev2 = 0.5*T - sqrt(0.25*T*T - det);
    writeLogRD("T = %e, det = %e, 0.25*T*T - det = %e, ev1 =  %e, ev2 = %e", T, det, 0.25*T*T - det, ev1, ev2);

    immutable l = sqrt(5.0*max(ev1, ev2) / globalMass);
    immutable b = sqrt(5.0*min(ev1, ev2) / globalMass);
    D = (( l - b ) / ( l + b ));
    if ( isNaN(D) ) {
      // This normally happens when the droplet is almost spherical, up to numerical errors;
      // we then can get a slightly negative value for 0.25*T*T - det, which NaNs the sqrt.
      // However, the droplet deformation is then supposed to be zero.
      D = 0.0;
    }
    writeLogRD("l = %e, b = %e, D = %e", l, b, D);
  }
  else {
    writeLogRW("Droplet deformation calculation is only available for 2d systems.");
  }

  double rel = sigma / previousSigma - 1.0;
  writeLogRI("Laplace calculation report for t = %d:", t);
  writeLogRI("  sigma = %e (%e relative change)", sigma, rel);
  writeLogRI("  radius = %e, inPres = %e, outPres = %e", measuredR, inPres, outPres);
  writeLogRI("  deformation = %e", D);
  writeToFile(gcc[0][1], initRadius, t, sigma, rel, measuredR, inPres, outPres, D );

  if ( startCheck > 0 && t >= startCheck ) {
    if ( ( !isNaN(relAccuracy) && relAccuracy > 0.0 && abs(rel) < relAccuracy ) || ( t >= timesteps ) ) {
      writeLogRN("Laplace calculation reached required accuracy %e.", relAccuracy );
      writeToFile(gcc[0][1], initRadius, t, sigma, rel, measuredR, inPres, outPres, D );
      timesteps = t; // jump to the end of the simulation
    }
    if ( isNaN(sigma) ) {
      writeLogF("Surface tension is NaN.");
    }
  }
  previousSigma = sigma;
}

/**
   Averages the fluids densities of a small cube of size $(D 2 * volumeAverage + 1) on the lattice, with offset $(D offset).

   Params:
     L = lattice
     offset = offset of the cube, from the origin
     volumeAverage = sets the size of the cube

   Returns: An array of average fluid densities, per fluid component.

   Bugs: Cubes at the edge of the domain don't wrap properly.
*/
private double[] volumeAveragedDensity(alias dims = T.lbconn.d, T)(ref T L, in ptrdiff_t[dims] offset, in int volumeAverage) if ( isLattice!T ) {
  alias conn = L.lbconn;
  double[] ldensity;
  ldensity.length = L.fluids.length;
  ldensity[] = 0.0;

  int[] lnsites;
  lnsites.length = L.fluids.length;
  lnsites[] = 0;

  L.precalculateDensities();

  foreach(immutable f, ref field; L.fluids) {
    foreach(immutable p, pop; field) {
      ptrdiff_t[field.d] gn;
      bool isInVolume = true;
      foreach(immutable vd; Iota!(0, conn.d) ) {
        gn[vd] = p[vd] + M.c[vd] * field.n[vd] - field.haloSize;
        if ( gn[vd] < ( -volumeAverage + offset[vd] ) || gn[vd] > ( volumeAverage + offset[vd] ) ) isInVolume = false;
      }
      if (isInVolume && isFluid(L.mask[p]) ) {
        ++lnsites[f];
	assert(L.density[f].isFresh());
        ldensity[f] += L.density[f][p];
      }
    }
  }

  double[] gdensity;
  int[] gnsites;
  gdensity.length = L.fluids.length;
  gnsites.length = L.fluids.length;

  int length = to!int(L.fluids.length);

  MPI_Allreduce(ldensity.ptr, gdensity.ptr, length, MPI_DOUBLE, MPI_SUM, M.comm);
  MPI_Allreduce(lnsites.ptr, gnsites.ptr, length, MPI_INT, MPI_SUM, M.comm);

  foreach(immutable i, ref e; gdensity) {
    e /= gnsites[i];
  }
  return gdensity;
}

/**
   Write Laplace information to file.
*/
private void writeToFile(in double gcc, in double initR, in uint t, in double sigma, in double rel, in double measuredR, in double inPres, in double outPres, in double D) {
  import dlbc.io.io;
  auto fileName = makeFilenameOutput!(FileFormat.Ascii)(fileNamePrefix, 0);

  writeLogRI("Writing to file '%s'.", fileName);

  string fileMode = "a";
  if ( ! appendToFile ) {
    fileMode = "w";
  }

  auto f = File(fileName, fileMode); // open for writing
  if ( ! appendToFile ) {
    f.writefln("#? %9s %12s %8s %13s %13s %12s %12s %12s %12s", "gcc", "initR", "t", "sigma", "rel", "measuredR", "inPres", "outPres", "D");
  }
  f.writefln("%e %e %8d %+e %+e %e %e %e %e", gcc, initR, t, sigma, rel, measuredR, inPres, outPres, D);
  // After the first output, start appending.
  appendToFile = true;
}
