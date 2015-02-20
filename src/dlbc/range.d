// Written in the D programming language.

/**
   Helper functions and templates for ranges.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

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

size_t LengthOf(T)() @property {
  static if ( hasLength!T) {
    return T.length;
  }
  else {
    return 1;
  }
}

template Iota(ptrdiff_t i, ptrdiff_t n) {
  import std.typetuple : TypeTuple;
  static if (n == 0) alias Iota = TypeTuple!();
  else alias Iota = TypeTuple!(i, Iota!(i + 1, n - 1));
}

