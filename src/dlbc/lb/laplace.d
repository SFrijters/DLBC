module dlbc.lb.laplace;

import dlbc.lattice;
import dlbc.parallel;
import dlbc.logging;
import dlbc.lb.lb;
import dlbc.range;

import std.conv: to;
import std.stdio;

void dumpLaplace(T)(ref T L, uint t) if ( isLattice!T ) {
  import std.algorithm: sum;
  import std.math;

  enum volumeAverage = 1;

  ptrdiff_t[T.dimensions] offsetIn;
  foreach(immutable i; Iota!(0, T.dimensions) ) {
    offsetIn[i] = to!int(L.gn[i] * 0.5);
  }
  ptrdiff_t[T.dimensions] offsetOut = 0;
  
  // writeLogRD("%s %s", offsetIn, offsetOut);
  // writeLogRD("inDen");
  auto inDen = L.volumeAveragedDensity(offsetIn, volumeAverage);
  //  writeLogRD("outDen");  
  auto outDen = L.volumeAveragedDensity(offsetOut, volumeAverage);

  assert(timestep != 0 || approxEqual(inDen[0], fluidDensity[0]));
  assert(timestep != 0 || approxEqual(inDen[1], fluidDensity[1]));
  assert(timestep != 0 || approxEqual(outDen[0], fluidDensity2[0]));
  assert(timestep != 0 || approxEqual(outDen[1], fluidDensity2[1]));

  double[] gMass;
  gMass.length = L.fluids.length;
  foreach(i, ref field; L.fluids) {
    gMass[i] = field.globalMass(L.mask);
  }
  //writeLogRD("gmass = %s", gMass);

  double effMass = gMass[0] - ( L.gsize * outDen[0]);
  double rpow3 = effMass / ( 4.0 / 3.0 * PI * ( inDen[0] - outDen[0] ) );
  double measuredR = pow(rpow3, 1.0/3.0);
  //writeLogRD("%f %f %f", effMass, rpow3, measuredR);

  auto inPres = pressure!d3q19(inDen);
  auto outPres = pressure!d3q19(outDen);

  static if ( T.dimensions == 3 ) {
    double sigma = measuredR * ( inPres - outPres ) / 2;
  }
  else static if ( T.dimensions == 2 ) {
    double sigma = measuredR * ( inPres - outPres );
  }
  else {
    assert(0);
  }

  assert(timestep != 0 || approxEqual(sigma, 0.0));

  writeLogRN("<LAPLACE> %8d %e %f %f %e %e %e", timestep, sigma, gccm[0][1], initRadius, measuredR, inPres, outPres );
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
double[] volumeAveragedDensity(alias dim = T.dimensions, T)(ref T L, in ptrdiff_t[dim] offset, in int volumeAverage) {
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

  double gdensity[];
  int gnsites[];
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

