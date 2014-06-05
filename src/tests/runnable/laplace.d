module tests.runnable.laplace;

version(unittest) {

  enum volumeAverage = 2;

  import std.conv;

  import tests.test;

  int runTest() {
    writeLogRN(makeHeaderString("Running test '%s'", __MODULE__));

    immutable string parameterFile = runnableTestPath ~ "laplace-parameters.txt";
    dlbc.parameters.parameterFileNames = [ parameterFile ];

    squelchLog();
    initParameters();
    initCommon();
    unsquelchLog();

    double[] radii = [ 5.0, 6.0, 7.0, 8.0, 9.0, 10.0 ];

    foreach(immutable r; radii) {
      dlbc.lb.init.sphereRadius.setParameter(r);
      writeLogRN("Performing simulation with dlbc.lb.init.sphereRadius = %f.", dlbc.lb.init.sphereRadius);
      // showParameters!(VL.Information, LRF.Root);

      auto L = Lattice!(gconn)(M);
      timestep = 0;
      initLattice(L);
      calculateLaplace(L);
      runTimeloop(L);
    }

    writeLogRN(makeHeaderString("Finished test '%s'", __MODULE__));
    return 0;
  }

  private void calculateLaplace(T)(ref T L) {
    import std.algorithm: sum;
    import std.math;

    auto inDen = insideDensity(L);
    auto outDen = outsideDensity(L);

    if ( timestep == 0 ) {
      assert(approxEqual(inDen[0], fluidDensity[0]));
      assert(approxEqual(inDen[1], fluidDensity[1]));
      assert(approxEqual(outDen[0], fluidDensity2[0]));
      assert(approxEqual(outDen[1], fluidDensity2[1]));
    }

    writeLogRD("outDen = %s", outDen);
    writeLogRD("inDen = %s", inDen);

    double[] gMass;
    gMass.length = L.fluids.length;
    foreach(i, ref field; L.fluids) {      
      gMass[i] = field.globalMass(L.mask);
    }
    writeLogRD("gmass = %s", gMass);

    double effMass = gMass[0] - ( L.gnx * L.gny * L.gnz * outDen[0]);
    double rpow3 = effMass / ( 4.0 / 3.0 * PI * ( inDen[0] - outDen[0] ) );
    double measuredR = pow(rpow3, 1.0/3.0);

    double inPresRaw = sum(inDen) / 3.0; // Speed of sound squared
    double outPresRaw = sum(outDen) / 3.0; // Speed of sound squared

    double inPres = inPresRaw + ( gcc[1] + gcc[2] ) *psi(inDen[0])*psi(inDen[1]) / 3.0;
    double outPres = outPresRaw + ( gcc[1] + gcc[2] ) *psi(outDen[0])*psi(outDen[1] / 3.0);

    writeLogRN("%f %f %f", measuredR, inPres, outPres);

  }

  private double[] outsideDensity(T)(ref T L) {
    double ldensity[];
    ldensity.length = L.fluids.length;
    ldensity[] = 0.0;

    int lnsites[];
    lnsites.length = L.fluids.length;
    lnsites[] = 0;

    foreach(i, ref field; L.fluids) {
      foreach( x, y, z, ref e; field) {
        auto gx = x + M.cx * field.nx - to!int(field.haloSize);
        auto gy = y + M.cy * field.ny - to!int(field.haloSize);
        auto gz = z + M.cz * field.nz - to!int(field.haloSize);
        if ( ( gx < 2*volumeAverage ) && ( gy < 2*volumeAverage ) && ( gz < 2*volumeAverage ) ) {
          lnsites[i]++;
          ldensity[i] += e.density();
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

    foreach(i, ref e; gdensity) {
      e /= gnsites[i];
    }
    return gdensity;
  }

  private double[] insideDensity(T)(ref T L) {
    double ldensity[];
    ldensity.length = L.fluids.length;
    ldensity[] = 0.0;

    int lnsites[];
    lnsites.length = L.fluids.length;
    lnsites[] = 0;

    foreach(i, ref field; L.fluids) {
      foreach( x, y, z, ref e; field) {
        auto gx = x + M.cx * field.nx - to!int(field.haloSize);
        auto gy = y + M.cy * field.ny - to!int(field.haloSize);
        auto gz = z + M.cz * field.nz - to!int(field.haloSize);
        if ( ( L.gnx / 2 - volumeAverage <= gx ) && ( gx < L.gnx / 2 + volumeAverage ) &&
             ( L.gny / 2 - volumeAverage <= gy ) && ( gy < L.gny / 2 + volumeAverage ) &&
             ( L.gnz / 2 - volumeAverage <= gz ) && ( gz < L.gnz / 2 + volumeAverage ) ) {
          lnsites[i]++;
          ldensity[i] += e.density();
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

    foreach(i, ref e; gdensity) {
      e /= gnsites[i];
    }
    return gdensity;
  }


}

