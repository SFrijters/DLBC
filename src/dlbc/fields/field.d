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

  T dist = 0.0;
  // writeLogRD("%s %s", rho0, v);
  foreach(i, e; population) {
    auto immutable vdotcv = v.dotProduct(cv[i]);
    dist[i] = rho0 * cw[i] * ( 1.0 + ( vdotcv / css ) + ( (vdotcv * vdotcv ) / ( 2.0 * css * css ) ) - ( ( vdotv * vdotv ) / ( 2.0 * css) ) );
  }
  return dist;
}

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

auto velocity(T, U)(const ref T population, const ref U conn) {
  auto immutable density = population.density();
  return velocity(population, density, conn);
}

auto velocityField(T, U)(ref T field, const ref U conn) {
  auto velocity = multidimArray!double[field.dimensions](field.nxH, field.nyH, field.nzH);
  foreach(z,y,x, ref pop; field.arr) {
    velocity[z,y,x] = pop.velocity(conn);
  }
  return velocity;
}

auto density(T)(const ref T pop) {
  import std.algorithm;
  return sum(pop[]);
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

