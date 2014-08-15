// Written in the D programming language.

/**
   Helper functions to validate Laplace's law for surface tension between fluid components.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.laplace;

import dlbc.lattice;
import dlbc.parallel;
import dlbc.logging;
import dlbc.lb.lb;
import dlbc.range;

import std.conv: to;
import std.stdio;

/**
   When to start checking relative accuracy of surface tension calculations.
*/
@("param") int startCheck = 0;
/**
   The iterations end when $(D sigma / previousSigma - 1) is smaller than this.
*/
@("param") double relAccuracy;

/**
   Keep sigma in memory for convergence criteria.
*/
private double previousSigma;

/**
   Calculate Laplace pressure and write it to screen.

   Params:
     L = lattice
     t = current time step
*/
void dumpLaplace(T)(ref T L, uint t) if ( isLattice!T ) {
  if ( ! enableShanChen ) return;
  assert(components == 2);
  import std.algorithm: any, sum;
  import std.math;

  enum volumeAverage = 1;

  ptrdiff_t[T.dimensions] offsetIn;
  foreach(immutable i; Iota!(0, T.dimensions) ) {
    offsetIn[i] = to!int(L.gn[i] * 0.5);
  }
  ptrdiff_t[T.dimensions] offsetOut = 0;

  if ( any(initOffset) ||
       ( fluidInit[0] != FluidInit.EqDistSphere && fluidInit[0] != FluidInit.EqDistSphereFrac ) ||
       ( fluidInit[1] != FluidInit.EqDistSphere && fluidInit[1] != FluidInit.EqDistSphereFrac ) ) {
    writeLogRW("Laplace pressure calculation assumes the presence of a centred sphere!");
  }

  // writeLogRD("%s %s", offsetIn, offsetOut);
  // writeLogRD("inDen");
  auto inDen = L.volumeAveragedDensity(offsetIn, volumeAverage);
  //  writeLogRD("outDen");
  auto outDen = L.volumeAveragedDensity(offsetOut, volumeAverage);

  assert(t != 0 || approxEqual(inDen[0], fluidDensity[0]));
  assert(t != 0 || approxEqual(inDen[1], fluidDensity[1]));
  assert(t != 0 || approxEqual(outDen[0], fluidDensity2[0]));
  assert(t != 0 || approxEqual(outDen[1], fluidDensity2[1]));

  auto inPres = pressure!d3q19(inDen);
  auto outPres = pressure!d3q19(outDen);

  double[] gMass;
  gMass.length = L.fluids.length;
  foreach(i, ref field; L.fluids) {
    gMass[i] = field.globalTotalMass(L.mask);
  }
  //writeLogRD("gmass = %s", gMass);

  double effMass = gMass[0] - ( L.gsize * outDen[0]);
  //writeLogRD("%f %f %f", effMass, rpow3, measuredR);

  // Laplace law has different prefactor depending on dimensions.
  static if ( T.dimensions == 3 ) {
    double measuredR = pow(effMass / ( 4.0 / 3.0 * PI * ( inDen[0] - outDen[0] ) ), 1.0/3.0);
    double sigma = measuredR * ( inPres - outPres ) / 2.0;
  }
  else static if ( T.dimensions == 2 ) {
    double measuredR = pow(effMass / ( PI * ( inDen[0] - outDen[0] ) ), 1.0/2.0);
    double sigma = measuredR * ( inPres - outPres );
  }
  else {
    assert(0);
  }

  assert(t != 0 || approxEqual(sigma, 0.0));

  double D;
  static if ( T.dimensions == 2 ) {
    import std.algorithm: min, max;
    double cutoff = 0.35;
    double Rx = 0.0;
    double Ry = 0.0;
    double M = 0.0;

    foreach(immutable p, pop; L.fluids[0]) {
      double den = pop.density();
      if ( den > cutoff ) {
        M += den;
        Rx += den*p[0];
        Ry += den*p[1];
      }
    }
    Rx /= M;
    Ry /= M;

    writeLogRN("%e %e %e", Rx, Ry, M);

    // Use CoM as offset

    double dx = Rx;
    double dy = Ry;

    double Ixx = 0.0;
    double Ixy = 0.0;
    double Iyy = 0.0;
    foreach(immutable p, pop; L.fluids[0]) {
      double x = p[0] - dx;
      double y = p[1] - dy;
      double den = pop.density();
      if ( den > cutoff ) {
        Ixx += den*(y*y);
        Ixy += den*(x*y);
        Iyy += den*(x*x);
      }
    }

    writeLogRN("%e %e %e", Ixx, Ixy, Iyy);
    
    double T = Ixx + Iyy;
    double det = Ixx * Iyy - Ixy * Ixy;
    double ev1 = 0.5*T + sqrt(0.25*T*T - det);
    double ev2 = 0.5*T - sqrt(0.25*T*T - det);

    writeLogRN("%e %e %e %e", T, det, ev1, ev2);

    // lb = scipy.linalg.eigvals([ [Iyy, Iyz ], [Iyz, Izz] ] )

    double l = sqrt(5.0*max(ev1, ev2) / M);
    double b = sqrt(5.0*min(ev1, ev2) / M);
    D = (( l - b ) / ( l + b ));

    writeLogRN("%e %e %e", l, b, D);

  }

  writeLogRN("<LAPLACE> %8d %e %e %e %e %e", t, sigma, measuredR, inPres, outPres, D );
  if ( t >= startCheck ) {
    double rel = abs(previousSigma / sigma - 1.0 );
    if ( ( !isNaN(relAccuracy) && relAccuracy > 0.0 && rel < relAccuracy ) || ( t >= timesteps ) ) {
      writeLogRI("<LAPLACE FINAL> %8d %e %f %f %e %e %e %e %e", t, sigma, gccm[0][1], initRadius, measuredR, inPres, outPres, rel, D );
      timesteps = t;
    }
    if ( isNaN(sigma) ) {
      writeLogRI("<LAPLACE FINAL> %8d %e %f %f %e %e %e %e %e", t, sigma, gccm[0][1], initRadius, measuredR, inPres, outPres, rel, D );
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
private double[] volumeAveragedDensity(alias dim = T.dimensions, T)(ref T L, in ptrdiff_t[dim] offset, in int volumeAverage) {
  double[] ldensity;
  ldensity.length = L.fluids.length;
  ldensity[] = 0.0;

  int[] lnsites;
  lnsites.length = L.fluids.length;
  lnsites[] = 0;

  foreach(immutable j, ref field; L.fluids) {
    foreach(immutable p, ref e; field) {
      ptrdiff_t[field.dimensions] gn;
      bool isInVolume = true;
      foreach(immutable i; Iota!(0, field.dimensions) ) {
        gn[i] = p[i] + M.c[i] * field.n[i] - field.haloSize;
        if ( gn[i] < -volumeAverage + offset[i] || gn[i] > volumeAverage + offset[i] ) isInVolume = false;
      }
      if (isInVolume) {
        // writeLogRD("In volume: %s %s.",p, gn);
        lnsites[j]++;
        ldensity[j] += e.density();
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

  // writeLogRD("densities: %s %s",gdensity,gnsites);

  return gdensity;
}

