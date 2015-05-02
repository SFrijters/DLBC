// Written in the D programming language.

/**
   Helpers to register functions and plugins.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.hooks;

import dlbc.logging;
import dlbc.lattice: LType;

/**
   Register of void functions without arguments, used to set up plugins, e.g. register more hooks.
*/
struct PluginRegister {
  alias VoidFunc = void function();

  private {
    RegisteredFunction!VoidFunc[] _registeredFunctions;
  }

  /**
     Add a single $(D VoidFunc) to the plugin register.

     Params:
       func = void function to be registered; cannot take any arguments
  */
  void registerPlugin(int line = __LINE__, string file = __FILE__,
			      string funcName = __FUNCTION__, string moduleName = __MODULE__)(VoidFunc func) {
    _registeredFunctions ~= RegisteredFunction!VoidFunc(moduleName, func, moduleName, line);
  }

  /**
     Execute all functions in the plugin register.
  */
  void execute() {
    writeLogRI("Initializing plugins.");
    foreach(rf; _registeredFunctions) {
      writeLogRD("Executing plugin initializer function for %s.", rf.moduleName);
      rf.func();
    }
  }
}

/// Ditto
PluginRegister pluginRegister;

/**
   Collection of $(D TVoidFunc), which can be registered and executed.
*/
struct TVoidHooks(T, string _hookName = "(none)") {
  alias TVoidFunc = void function(ref T);

  private {
    RegisteredFunction!TVoidFunc[] _registeredFunctions;
  }

  /**
     Register a single $(D TVoidFunc).

     Params:
       func = void function to be registered; takes a single argument of type $(D T)
       functionName = human readable function name, used for debugging only
  */
  void registerFunction(int line = __LINE__, string file = __FILE__,
			string funcName = __FUNCTION__, string moduleName = __MODULE__)(TVoidFunc func, string functionName) {
    _registeredFunctions ~= RegisteredFunction!TVoidFunc(functionName, func, moduleName, line);
    writeLogRD("Registered function '%s' from %s line %d at address %s.", functionName, moduleName, line, func);
  }


  /**
     Show a human-readable list of all registered functions.
  */
  void showAllRegisteredFunctions(VL vl, LRF logRankFormat)() {
    string[] rfNames;
    foreach(rf; _registeredFunctions) {
      rfNames ~= rf.moduleName ~ "." ~ rf.functionName;
    }
    writeLog!(vl, logRankFormat)("Functions registered for %s: %s", _hookName, rfNames);
  }

  /**
     Execute all registered functions, passing a single parameter.

     Params:
       arg = parameter to be passed to all functions as first and only argument
  */
  void execute(ref T arg) {
    foreach(rf; _registeredFunctions) {
      writeLogRD("Executing registered function '%s'.", rf.functionName);
      rf.func(arg);
    }
  }

  /**
     Return the number of registered functions.
  */
  auto length() {
    return _registeredFunctions.length;
  }
}

private struct RegisteredFunction(T) {
  /// Human-readable name of a function.
  string functionName;
  /// Function pointer.
  T func;
  /// Name of the module from which the function is registered.
  string moduleName;
  /// Line number where the function is registered.
  int line;
}

