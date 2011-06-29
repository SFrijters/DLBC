import std.stdio;
import std.algorithm;
import std.datetime;
import std.conv;
import std.string;
import core.thread;

import mpi;

class lattice {
  int i;
}

void writelog(T...)(T args) {
  static if (!T.length) {
    writeln();
  }
  else {
    static if (is(T[0] : string)) {
      SysTime tNow = Clock.currTime;
      string prefix = format("%#2.2d:%#2.2d:%#2.2d",tNow.hour,tNow.minute,tNow.second);
      args[0] = prefix ~ " [TEST] " ~ args[0];
      if (canFind(args[0], "%")) {
	writefln(args);
	return;
      }
    }
    // not a string, or not a formatted string
    writeln(args);
  }
}

int main( string[] args ) {

  int rank, size;

  // C-style dummy arg vector for MPI_Init
  int    argc = cast(int) args.length;
  char** argv = null;

  MPI_Init( &argc, &argv );
  MPI_Comm_rank( MPI_COMM_WORLD, &rank );
  MPI_Comm_size( MPI_COMM_WORLD, &size );

  if (rank > 0) Thread.sleep(10_000_000);

  writelog("Hello World from process %d of %d.", rank, size );
  writelog();

  if (rank > 0) Thread.sleep(dur!("seconds")(1));

  MPI_Barrier( MPI_COMM_WORLD );

  debug(2) {
    if (rank == 0) {
      writelog( "Rank 0 reporting.");
    }
  }

  MPI_Finalize();

  return 0;
}

