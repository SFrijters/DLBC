// Written in the D programming language.

/**
   Helpers to register functions.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.hooks;

import dlbc.lattice;
import dlbc.lb.connectivity;
import dlbc.logging;

alias LatticeHooks = VoidHooks!(Lattice!gconn);

struct VoidHooks(T) {
  alias TVoidFunc = void function(ref T);
  
  private {
    TVoidFunc[] _hookedFunctions;
  }

  void registerFunction(int line = __LINE__, string file = __FILE__,
			string funcName = __FUNCTION__)(TVoidFunc fun) {
    _hookedFunctions ~= fun;
    writeLogRD("Registered function from %s line %d at address %s.", file, line, fun);
  }

  void execute(ref T L) {
    foreach(fun; _hookedFunctions) {
      writeLogRD("Executing registered function at address %s.", fun);
      fun(L);
    }
  }

  auto length() {
    return _hookedFunctions.length;
  }
}

