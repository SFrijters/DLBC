module tests.runnable.laplace;

version(unittest) {

  import std.conv;
  import std.stdio;

  import tests.test;

  immutable string parameterFile = runnableTestPath ~ "laplace-parameters.txt";
  immutable string resultsFile = runnableTestPath ~ "laplace-results.dat";

  int runTest() {
    writeLogRN(makeHeaderString("Running test '%s'", __MODULE__));

    dlbc.parameters.parameterFileNames = [ parameterFile ];

    squelchLog();
    initParameters();
    unsquelchLog();

    double[] radii = [ 5.0, 6.0, 7.0, 8.0, 9.0, 10.0 ];
    double[][] gccArray = [ 
                        // [ 0.0, 0.1, 0.1, 0.0 ],
                           [ 0.0, 0.2, 0.2, 0.0 ],
                           [ 0.0, 0.225, 0.225, 0.0 ],
                           [ 0.0, 0.25, 0.25, 0.0 ],
                           [ 0.0, 0.275, 0.275, 0.0 ],
                           [ 0.0, 0.3, 0.3, 0.0 ],
                           [ 0.0, 0.325, 0.325, 0.0 ],
                           [ 0.0, 0.35, 0.35, 0.0 ],
                           [ 0.0, 0.375, 0.375, 0.0 ],
                           [ 0.0, 0.4, 0.4, 0.0 ],
                           [ 0.0, 0.425, 0.425, 0.0 ],
                           [ 0.0, 0.45, 0.45, 0.0 ],
                           [ 0.0, 0.475, 0.475, 0.0 ],
                           [ 0.0, 0.5, 0.5, 0.0 ],
			  ];

    enum volumeAverage = 2;

    if ( M.isRoot() ) {
      auto f = File(resultsFile, "w");
      f.writefln("#?     t %13s %13s %13s %13s %13s %13s", "gcc", "R", "sigma", "R_d", "P_in", "P_out");
    }

    foreach(g; gccArray) {
      foreach(immutable r; radii) {
	dlbc.lb.init.sphereRadius.setParameter(r);
	dlbc.lb.force.gcc.setParameter(g);
	writeLogRN("Performing simulation with:\n    dlbc.lb.force.gcc = %s\n    dlbc.lb.init.sphereRadius = %f", dlbc.lb.force.gcc, dlbc.lb.init.sphereRadius);
	initCommon();

	auto L = Lattice!(gconn.d)(M);
	timestep = 0;
	initLattice(L);
	L.calculateLaplace(volumeAverage);
	runTimeloop(L);
	L.calculateLaplace(volumeAverage);
	// auto colour = colourField(L.fluids[0], L.fluids[1], L.mask);
	// colour.dumpField("colour-"~fieldNames[0]~"-"~fieldNames[1],timestep);
      }
    }

    writeLogRN(makeHeaderString("Finished test '%s'", __MODULE__));
    return 0;
  }

  private void calculateLaplace(T)(ref T L, const int volumeAverage) {
    import std.algorithm: sum;
    import std.math;

    auto inDen = L.insideDensity(volumeAverage);
    auto outDen = L.outsideDensity(volumeAverage);

    if ( timestep == 0 ) {
      assert(approxEqual(inDen[0], fluidDensity[0]));
      assert(approxEqual(inDen[1], fluidDensity[1]));
      assert(approxEqual(outDen[0], fluidDensity2[0]));
      assert(approxEqual(outDen[1], fluidDensity2[1]));
    }

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

    auto inPres = pressure!gconn(inDen);
    auto outPres = pressure!gconn(outDen);

    double sigma = measuredR * ( inPres - outPres ) / 2;

    if ( timestep == 0 ) {
      assert(approxEqual(sigma, 0.0));
    }

    writeLogRD("<LAPLACE> %8d %f %f %f %f %f %f", timestep, gccm[0][1], sphereRadius, sigma, measuredR, inPres, outPres );

    if ( M.isRoot() ) {
      auto f = File(resultsFile, "a");
      f.writefln("%8d %+e %+e %+e %+e %+e %+e", timestep, gccm[0][1], sphereRadius, sigma, measuredR, inPres, outPres );
    }
  }

  private double[] outsideDensity(T)(ref T L, const int volumeAverage) {
    double ldensity[];
    ldensity.length = L.fluids.length;
    ldensity[] = 0.0;

    int lnsites[];
    lnsites.length = L.fluids.length;
    lnsites[] = 0;

    foreach(immutable i, ref field; L.fluids) {
      foreach(immutable p, ref e; field) {
        auto gx = p[0] + M.c[0] * field.n[0] - to!int(field.haloSize);
        auto gy = p[1] + M.c[1] * field.n[1] - to!int(field.haloSize);
        auto gz = p[2] + M.c[2] * field.n[2] - to!int(field.haloSize);
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

  private double[] insideDensity(T)(ref T L, const int volumeAverage) {
    double ldensity[];
    ldensity.length = L.fluids.length;
    ldensity[] = 0.0;

    int lnsites[];
    lnsites.length = L.fluids.length;
    lnsites[] = 0;

    foreach(immutable i, ref field; L.fluids) {
      foreach(immutable p, ref e; field) {
        auto gx = p[0] + M.c[0] * field.n[0] - to!int(field.haloSize);
        auto gy = p[1] + M.c[1] * field.n[1] - to!int(field.haloSize);
        auto gz = p[2] + M.c[2] * field.n[2] - to!int(field.haloSize);
        if ( ( L.gn[0] / 2 - volumeAverage <= gx ) && ( gx < L.gn[0] / 2 + volumeAverage ) &&
             ( L.gn[1] / 2 - volumeAverage <= gy ) && ( gy < L.gn[1] / 2 + volumeAverage ) &&
             ( L.gn[2] / 2 - volumeAverage <= gz ) && ( gz < L.gn[2] / 2 + volumeAverage ) ) {
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

