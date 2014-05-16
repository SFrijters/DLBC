// Written in the D programming language.

/**
Implementation of scalar and vector fields on the lattice.

Copyright: Stefan Frijters 2011-2014

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.fields.field;

import dlbc.connectivity;
import dlbc.logging;
import dlbc.parallel;

import unstd.multidimarray;
import unstd.generictuple;

/**
   The $(D Field) struct is designed as a template to hold scalars or vectors of
   arbitrary type on a lattice of arbitrary dimension (this will normally match
   the dimensionality of the underlying $(D Lattice) struct).

   Params:
     T = datatype to be held
     dim = dimensionality of the field
     hs = size of the halo region
*/
struct Field(T, uint dim, uint hs) {
  static assert(dim > 1, "1D fields are not supported.");
  static assert(dim == 3, "Non-3D fields not yet implemented.");

  MultidimArray!(T, dim) arr, sbuffer, rbuffer;

  private uint _dimensions = dim;
  private uint[dim] _lengths;
  private uint _haloSize = hs;
  private uint[dim] _lengthsH;

  /**
     Number of dimensions of the field.
  */
  @property auto dimensions() {
    return _dimensions;
  }

  /**
     Lengths of the physical dimensions of the field.
  */
  @property auto lengths() {
    return _lengths;
  }

  /**
     Alias for the first component of $(D lengths).
  */
  @property auto nx() {
    return _lengths[0];
  }

  /**
     Alias for the second component of $(D lengths).
  */
  @property auto ny() {
    return _lengths[1];
  }

  /**
     Alias for the third component of $(D lengths), if $(D dim) > 2.
  */
  static if ( dim > 2 ) {
    @property auto nz() {
      return _lengths[2];
    }
  }

  /**
     Size of the halo (on each side).
  */
  @property auto haloSize() {
    return _haloSize;
  }

  /**
     Length of the physical dimensions with added halo on both sides, i.e. the stored field.
  */
  @property auto lengthsH() {
    return _lengthsH;
  }

  /**
     Alias for the first component of $(D lengthsH).
  */
  @property auto nxH() {
    return _lengthsH[0];
  }

  /**
     Alias for the second component of $(D lengthsH).
  */
  @property auto nyH() {
    return _lengthsH[1];
  }

  /**
     Alias for the third component of $(D lengthsH), if $(D dim) > 2.
  */
  static if ( dim > 2 ) {
    @property auto nzH() {
      return _lengthsH[2];
    }
  }

  /**
     MPI datatype corresponding to type $(D T).
  */
  private MPI_Datatype mpiType = mpiTypeof!T;
  private uint mpiLength = mpiLengthof!T;

  /**
     Allows to access the underlying multidimensional array correctly.
  */
  alias arr this;

  /**
     A $(D Field) is constructed by specifying the size of the physical domain and the required halo size.

     Params:
       lengths = lengths of the dimensions of the physical domain
  */
  this (const uint[dim] lengths) {
    writeLogRD("Initializing %s local field of type '%s' with halo of thickness %d.", lengths.makeLengthsString, T.stringof, haloSize);

    this._lengths = lengths;
    // Why doesn't scalar addition work?
    this._lengthsH[0] = lengths[0] + (2* hs);
    this._lengthsH[1] = lengths[1] + (2* hs);
    this._lengthsH[2] = lengths[2] + (2* hs);

    arr = multidimArray!T(nxH, nyH, nzH);
  }

  /**
     This variant of opApply loops over the physical part of the lattice only
     and overloads the opApply of the underlying multidimArray.
     If the foreach loop is supplied with a reference to the array directly
     it will loop over all lattice sites instead (including the halo).

     Example:
     ----
     foreach(x, y, z, ref el; sfield) {
       // Loops over physical sites of scalar field only.
     }

     foreach(x, y, z, ref el; sfield.arr) {
       // Loops over all lattice sites of scalar field.
     }
     ---
  */
  int opApply(int delegate(RepeatTuple!(arr.dimensions, size_t), ref T) dg) {
    if(!elements)
      return 0;

    RepeatTuple!(arr.dimensions, size_t) indices = haloSize;
    indices[$ - 1] = -1 + haloSize;

    for(;;) {
      foreach_reverse(const plane, ref index; indices) {
	if(++index < arr.lengths[plane] - haloSize)
	  break;
	else if(plane)
	  index = haloSize;
	else
	  return 0;
      }

      if(const res = dg(indices, arr._data[getOffset(indices)]))
	return res;
    }
  }

  /**
     The halo of the field is exchanged with all 6 neighbours, according to 
     the haloSize specified when the field was created. The data is first
     stored in the send buffer $(D sbuffer), and data from the neighbours is
     received in $(D rbuffer). Because the slicing is performed in an
     identical fashion on all processes, we can easily put the data in the
     correct spot in the main array.

     Params:
       haloSize = width of the halo to be exchanged; this can be smaller than
                  the halo that is held in memory
  */
  void exchangeHalo(uint haloSize = hs)() {
    static assert( haloSize <= hs, "Requested size of halo exchange cannot be larger than halo size of field.");

    writeLogRD("Performing halo exchange of size %d.", haloSize);

    uint buflen;
    MPI_Status mpiStatus;

    uint haloOffset = this._haloSize - haloSize;

    uint lus = this._haloSize + haloOffset + haloSize;
    uint uus = this._haloSize + haloOffset;
    uint lls = this._haloSize + haloOffset;
    uint uls = this._haloSize + haloOffset + haloSize;

    uint lur = haloOffset + haloSize;
    uint uur = haloOffset;
    uint llr = haloOffset;
    uint ulr = haloOffset + haloSize;

    // Send to positive x
    buflen = (ny + 2*haloSize) * (nz + 2*haloSize) * haloSize * mpiLength;
    rbuffer = multidimArray!T(haloSize, (ny + 2*haloSize), (nz + 2*haloSize));
    sbuffer = arr[$-lus .. $-uus, haloOffset..$-haloOffset, haloOffset..$-haloOffset].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, M.comm, &mpiStatus);
    arr[llr..ulr, haloOffset..$-haloOffset, haloOffset..$-haloOffset] = rbuffer;
    // Send to negative x
    sbuffer = arr[lls..uls, haloOffset..$-haloOffset, haloOffset..$-haloOffset].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, M.comm, &mpiStatus);
    arr[$-lur .. $-uur, haloOffset..$-haloOffset, haloOffset..$-haloOffset] = rbuffer;

    // Send to positive y
    buflen = (nx + 2*haloSize) * (nz + 2*haloSize) * haloSize * mpiLength;
    rbuffer = multidimArray!T((nx + 2*haloSize), haloSize, (nz + 2*haloSize));
    sbuffer = arr[haloOffset..$-haloOffset, $-lus..$-uus, haloOffset..$-haloOffset].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, M.comm, &mpiStatus);
    arr[haloOffset..$-haloOffset, llr..ulr, haloOffset..$-haloOffset] = rbuffer;
    // Send to negative y
    sbuffer = arr[haloOffset..$-haloOffset, lls..uls, haloOffset..$-haloOffset].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, M.comm, &mpiStatus);
    arr[haloOffset..$-haloOffset, $-lur..$-uur, haloOffset..$-haloOffset] = rbuffer;

    // Send to positive z
    buflen = (nx + 2*haloSize) * (ny + 2*haloSize) * haloSize * mpiLength;
    rbuffer = multidimArray!T((nx + 2*haloSize), (ny + 2*haloSize), haloSize);
    sbuffer = arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, $-lus..$-uus].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbz[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nbz[0], 0, M.comm, &mpiStatus);
    arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, llr..ulr] = rbuffer;
    // Send to negative z
    sbuffer = arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, lls..uls].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbz[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nbz[1], 0, M.comm, &mpiStatus);
    arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, $-lur..$-uur] = rbuffer;
  }

  /**
     Extension for the toString function of the multidimArray, allowing for a fourth dimension.
     It also takes into account verbosity levels and rank formatting.

     Params:
       vl = verbosity level to write at
       logRankFormat = which processes should write
  */
  void show(VL vl, LRF logRankFormat)() {
    writeLog!(vl, logRankFormat)(this.toString());
  }
}

void collideField(T, U)(ref T field, const ref U conn) {
  enum omega = 1.0;
  foreach(ref population; field.byElementForward) {
    auto eqPop = eqDist(population, conn);
    // writeLogRD("%s %s", e, boltz);
    population[] -= omega * ( population[] - eqPop[]);
    // writeLogRD("%s", e);
  }
}

auto eqDist(T, U)(const ref T population, const ref U conn) {
  import std.numeric: dotProduct;

  auto immutable cv = conn.velocities;
  auto immutable cw = conn.weights;
  auto immutable rho0 = population.density();
  auto immutable v = population.velocity(rho0, conn);
  enum css = 1.0/3.0;

  auto immutable vdotv = v.dotProduct(v);

  T dist;
  // writeLogRD("%s %s %s %s", rho0, v, vdotv, css);
  foreach(i, e; cv) {
    auto immutable vdotcv = v.dotProduct(e);
    dist[i] = rho0 * cw[i] * ( 1.0 + ( vdotcv / css ) + ( (vdotcv * vdotcv ) / ( 2.0 * css * css ) ) - ( ( vdotv * vdotv ) / ( 2.0 * css) ) );
    // writeLogRD("%2d %10s %10s %10s %10s", i, cv[i], cw[i], vdotcv, dist[i]);
  }
  // writeLogRD("%s %s %s", dist, density(dist), velocity(dist, conn));
  auto den = dist.density();
  foreach(ref e; dist) {
    e /= ( den / rho0 );
  }
  // writeLogRD("%s %s %s", dist, density(dist), velocity(dist, conn));
  return dist;
}

/**
   Calculates the local velocity of a population \(\vec{n}\): \(\vec{u}(\vec{n}) = \frac{\sum_r n_r \vec{c}__r}{\rho_0(\vec{n})}\).

   Params:
     population = population vector \(\vec{n}\)
     density = if the density \(\rho_0\) has been pre-calculated, it can be passed directly
     conn = connectivity

   Returns:
     local velocity \(\vec{u}(\vec{n})\)
*/
auto velocity(T, U)(const ref T population, const double density, const ref U conn) {
  auto immutable cv = conn.velocities;
  assert(population.length == cv.length);

  double[3] vel = 0.0;
  foreach(i, e; population) {
    vel[0] += e * cv[i][0];
    vel[1] += e * cv[i][1];
    vel[2] += e * cv[i][2];
  }
  vel[0] /= density;
  vel[1] /= density;
  vel[2] /= density;
  return vel;
}

/// Ditto
auto velocity(T, U)(const ref T population, const ref U conn) {
  auto immutable density = population.density();
  return velocity(population, density, conn);
}

///
unittest {
  auto d3q19 = new Connectivity!(3,19);
  double[19] pop = [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  auto den = density(pop);
  auto vel = velocity(pop, d3q19);
  assert(vel == [1,1,0]);

  pop = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];

  den = density(pop);
  vel = velocity(pop, den, d3q19);
  assert(den == 0.5);
  assert(vel == [-0.2,-0.2,0.2]);
}

auto velocityField(T, U)(ref T field, const ref U conn) {
  auto velocity = multidimArray!double[field.dimensions](field.nxH, field.nyH, field.nzH);
  foreach(z,y,x, ref pop; field.arr) {
    velocity[z,y,x] = pop.velocity(conn);
  }
  return velocity;
}

/**
   Calculates the local density of a population \(\vec{n}\): \(\rho_0(\vec{n}) = \sum_r n_r\).

   Params:
     population = population vector \(\vec{n}\)

   Returns:
     local density \(\rho_0(\vec{n})\)
*/
auto density(T)(const ref T population) {
  import std.algorithm;
  return sum(population[]);
}

///
unittest {
  double[19] pop = [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  auto den = density(pop);
  assert(den == 0.1);

  pop = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];
  den = density(pop);
  assert(den == 0.5);
}

auto densityField(T)(ref T field) {
  auto density = multidimArray!double(field.nxH, field.nyH, field.nzH);
  foreach(z,y,x, ref pop; field.arr) {
    density[z,y,x] = pop.density();
  }
  return density;
}

auto localMass(T)(ref T field) {
  import std.algorithm;
  double mass = 0.0;
  int cnt = 0;
  foreach(z, y, x, ref e; field) {
    mass += e.density();
    cnt++;
  }
  return mass;
}

auto localDensity(T)(ref T field) {
  auto size = field.nx * field.ny * field.nz;
  return localMass(field) / size;
}

auto globalMass(T)(ref T field) {
  auto localMass = localMass(field);
  typeof(localMass) globalMass;
  MPI_Allreduce(&localMass, &globalMass, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  return globalMass;
}

auto globalDensity(T)(ref T field) {
  auto size = field.nx * field.ny * field.nz * M.size;
  return globalMass(field) / size;
}

auto momentum(T, U)(const ref T population, const ref U conn) {
  auto density = population.density();
  auto velocity = velocity(population, density, conn);
  foreach( ref e; velocity) {
    e *= density * density;
  }
  return velocity;
}

auto momentumField(T, U)(const ref T population, const ref U conn) {
  auto momentum = multidimArray!double[field.dimensions](field.nxH, field.nyH, field.nzH);
  foreach(z,y,x, ref population; field.arr) {
    momentum[z,y,x] = population.momentum(conn);
  }
  return momentum;
}

auto localMomentum(T, U)(ref T field, const ref U conn) {
  double[3] momentum = 0.0;
  foreach(z, y, x, ref e; field) {
    auto mom = e.momentum(conn);
    momentum[0] += mom[0];
    momentum[1] += mom[1];
    momentum[2] += mom[2];
  }
  return momentum;
}

auto globalMomentum(T, U)(ref T field, const ref U conn) {
  auto localMomentum = field.localMomentum(conn);
  typeof(localMomentum) globalMomentum;
  MPI_Allreduce(&localMomentum, &globalMomentum, field.dimensions, MPI_DOUBLE, MPI_SUM, M.comm);
  return globalMomentum;
}

/**
   Advect a population field over one time step. The advected values are first
   stored in the $(D tempField), and at the end the fields are swapped.

   Params:
     field = field to be advected
     tempField = temporary field of the same size and type as $(D field)
     conn = connectivity
*/
void advectField(T, U)(ref T field, ref T tempField, const ref U conn) {
  import std.algorithm: swap;

  assert(field.dimensions == tempField.dimensions);
  auto immutable cv = conn.velocities;
  foreach( z, y, x, ref population; tempField) {
    assert(population.length == cv.length);
    foreach( i, ref c; population ) {
      c = field[z-cv[i][2], y-cv[i][1], x-cv[i][0]][i];
    }
  }
  swap(field, tempField);
}

///
unittest {
  import dlbc.fields.init;

  globalVerbosityLevel = VL.Off;
  startMpi([]);
  reorderMpi();
  globalVerbosityLevel = VL.Debug;

  if ( M.size == 8 ) {
    auto d3q19 = new Connectivity!(3,19);
    uint[3] lengths = [ 16, 16 ,16 ];
    auto field = Field!(double[19], 3, 2)(lengths);
    auto temp = Field!(double[19], 3, 2)(lengths);

    field.initConst(0);
    if ( M.isRoot ) {
      field[2,2,2] = [42, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 ,15, 16 ,17 ,18];
    }
    field.exchangeHalo();
    field.advectField(temp, d3q19);
    
    if ( M.rank == 0 ) {
      // writeLogI("[2,2,2][0] = %f",field[2,2,2][0]);
      // writeLogI("[2,2,3][1] = %f",field[2,2,3][1]);
      // writeLogI("[2,3,2][3] = %f",field[2,3,2][3]);
      // writeLogI("[3,2,2][5] = %f",field[3,2,2][5]);
      // writeLogI("[2,3,3][7] = %f",field[2,3,3][7]);
      // writeLogI("[3,3,2][9] = %f",field[3,3,2][9]);
      // writeLogI("[3,2,3][11] = %f",field[3,2,3][11]);
      assert(field[2,2,2][0] == 42);
      assert(field[2,2,3][1] == 1);
      assert(field[2,3,2][3] == 3);
      assert(field[3,2,2][5] == 5);
      assert(field[2,3,3][7] == 7);
      assert(field[3,3,2][9] == 9);
      assert(field[3,2,3][11] == 11);
    }
    else if ( M.rank == 1 ) {
      // writeLogI("[2,2,17][2] = %f",field[2,2,17][2]);
      // writeLogI("[2,3,17][8] = %f",field[2,3,17][8]);
      assert(field[2,2,17][2] == 2);
      assert(field[2,3,17][8] == 8);
    }
    else if ( M.rank == 2 ) {
      // writeLogI("[2,17,2][4] = %f",field[2,17,2][4]);
      // writeLogI("[3,17,2][10] = %f",field[3,17,2][10]);
      // writeLogI("[2,17,3][13] = %f",field[2,17,3][13]);
      assert(field[2,17,2][4] == 4);
      assert(field[3,17,2][10] == 10);
      assert(field[2,17,3][13] == 13);
    }
    else if ( M.rank == 3 ) {
      // writeLogI("[2,17,17][14] = %f",field[2,17,17][14]);
      assert(field[2,17,17][14] == 14);
    }
    else if ( M.rank == 4 ) {
      // writeLogI("[17,2,2][6] = %f",field[17,2,2][6]);
      // writeLogI("[17,2,3][12] = %f",field[17,2,3][12]);
      // writeLogI("[17,3,2][15] = %f",field[17,3,2][15]);
      assert(field[17,2,2][6] == 6);
      assert(field[17,2,3][12] == 12);
      assert(field[17,3,2][15] == 15);
    }
    else if ( M.rank == 5) {
      // writeLogI("[17,2,17][18] = %f",field[17,2,17][18]);
      assert(field[17,2,17][18] == 18);
    }
    else if ( M.rank == 6) {
      // writeLogI("[17,17,2][16] = %f",field[17,17,2][16]);
      assert(field[17,17,2][16] == 16);
    }
  }
  else {
    writeLogRW("Unittest for advection requires M.size == 8.");
  }
}
  
