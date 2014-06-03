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
    alias BaseElementType = T;
  }
  else static if ( rank!T == 1 ) {
    alias BaseElementType = ElementType!T;
  }
  else {
    alias BaseElementType = BaseElementType!(ElementType!(T));
  }
}

size_t LengthOf(T)() {
  static if ( hasLength!T) {
    return T.length;
  }
  else {
    return 1;
  }
}

