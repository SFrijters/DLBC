module dlbc.range;

import std.range;
import std.traits;

template rank(T) {
  static if ( isArray!T ) {
    enum size_t rank = 1 + rank!(ElementType!T);
  }
  else {
    enum size_t rank = 0;
  }
}

template BaseElementType(T) {
  static if ( rank!T == 0 ) {
    alias T BaseElementType;
  }
  else static if ( rank!T == 1 ) {
    alias ElementType!T BaseElementType;
  }
  else {
    alias BaseElementType!(ElementType!(T)) BaseElementType;
  }
}

