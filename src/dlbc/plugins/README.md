# Plugins

Plugins are stored in or below this directory. They are detected automatically as part of the build process.
To add any parameters to the parameter parser, the shell script `get-plugin-modules.sh` is run to generate
the file `plist.d` in this directory. If it exists, it will be imported into `dlbc.parameters` to add
the plugin modules that contain `@("param")` variables.

## Example

    module dlbc.plugins.example;

    import dlbc.lattice;
    import dlbc.lb.advection;
    import dlbc.lb.connectivity;
    import dlbc.hooks;

    @("param") bool enableThis; // Will be added to the parameter parser automagically.

    shared static this() {
      // The module constructor is used to register an initialisation function which
      // takes no arguments and returns void.
      pluginRegister.registerPlugin(&initializePlugin);
    }

    void initializePlugin() {
      // We can use this function to register more functions to the relevant hooks.
      // In this case, we want to do something after advection.
      // These functions are assumed to return void and take the lattice as the only argument.
      if ( enableThis ) {
        postAdvectionHooks.registerFunction(&exampleFunction!(Lattice!gconn), "example");
      }
    }

    void exampleFunction(T)(ref T L) if ( isLattice!T ) {
      // Do something, possibly involving the lattice L.
    }

