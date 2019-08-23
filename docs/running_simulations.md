---
layout: default
title: Running a simulation
mathjax: true
---

# Running a simulation

## Using the wrapper

The core of QDYN is a Fortran code. While the format of its input and output files is well defined, we find it more convenient to set up the input parameters, perform simulations, and read the output data within a MATLAB (`qdyn.m`) or Python (`pyqdyn.py`) environment. The operation of both these wrappers is detailed below.

### MATLAB wrapper

You first need to set in MATLAB the full path to the `src` directory, for instance:

```
addpath ~/qdyn-read-only/src
```

> **Tip for Mac users**: if you get an error message related to `gfortran` libraries (e.g. `libgfortran.3.dylib`) when running `qdyn` in MATLAB, execute:
>
> ```
> setenv('DYLD_LIBRARY_PATH', '/usr/local/bin')
> ```
>
> The second argument should be the path to your `gfortran` libraries (sometimes set to `/opt/local/lib/libgcc`).

The general usage syntax is:

```
[pars, ot, ox] = qdyn(mode, [parsin], ['Property', Value, ...])
```

The default input values can be listed by executing:

```
pars = qdyn('set')
```

Permitted arguments for `mode` are:

|   Value   | Description                                                  |
| :-------: | ------------------------------------------------------------ |
|  `'set'`  | Outputs the default parameter structure (`pars`) or overrides it with fields present in the structure `parsin` or with *Property-Value* pairs |
| `'write'` | Sets parameters and writes the QDYN input file               |
|  `'run'`  | Sets parameters, writes the input file, and runs the simulation |
| `'read'`  | Reads parameters and outputs from a previous simulation      |

The `[parsin]` list is a structure to override the default parameters, using *Property-Value* pairs. See the [section on input parameters](#simulation-input-parameters) below.



### Python wrapper

As an alternative to the MATLAB wrapper, users can chose to generate their input files through a Python wrapper, called `pyqdyn.py`. While the variable naming conventions are the same as in the MATLAB wrapper, the data structures and operation modes are somewhat different. The Python wrapper relies heavily on dictionary objects for both the simulation parameters and the generated mesh. A basic operation workflow looks as follows:

1. After importing the `pyqdyn.py` module, instantiate QDYN as: `p = qdyn()`

2. Create a dictionary with simulation parameters to override the default values, for example:

   ```python
   # General simulation parameters
   set_dict = {
       "FAULT_TYPE": 1,
       "ACC": 1e-10,
       "SOLVER": 2,
       "TMAX": 20,
       "MESHDIM": 1,
       "SIGMA": 5e6,
       "L": 100e3,
       "W": 100e5,
       "FRICTION_MODEL": "RSF",
   }
   
   # RSF parameters
   set_dict_RSF = {
       "RNS_LAW": 0,
       "THETA_LAW": 1,
       "A": 0.001,
       "B": 0.0015,
       "DC": 1e-5,
       "MU_SS": 0.6,
       "V_SS": 1e-6,
   }
   
   # Merge dicts
   set_dict["SET_DICT_RSF"] = set_dict_RSF
   ```

3. Pass the parameter values to the QDYN instance and generate the mesh:

   ```python
   p.settings(set_dict)
   p.render_mesh()
   ```

4. The mesh is now populated the values defined in `set_dict` (along with the default settings, if left unchanged). Individual mesh node parameters can be accessed through `p.mesh_dict["PARAM"][element]`, where `"PARAM"` is a given variable name (see [input parameters](#simulation-input-parameters)), and `element` is the index of the node (note that Python index count starts at 0, and not at 1 like in MATLAB). The mesh is stored as a set of NumPy arrays, so slicing and vector operations are permitted (for instance: `p.mesh_dict["SIGMA"][50:100] = 10e6`).

5. Write the input file and run the simulation as:

   ```python
   p.write_input()
   p.run()
   ```

6. During and after the simulation, the current/final simulation output can be read using `p.read_output()`. This creates two new objects contained in the QDYN instance: `p.ot` contains the time series data, and `p.ox` contains the fault snapshots. See the section "[Simulation output structure](#simulation-output-structure)" for a list of output parameters. An example of how to access output data:

   ```python
   time = p.ot["t"]  # Vector of simulation time steps
   Vmax = p.ot["V_max"]  # Vector of maximum slip velocity
   
   # Import matplotlib and plot results
   import matplotlib.pyplot as plt
   plt.plot(time, Vmax)
   plt.show()
   ```





## Simulation input parameters



**Parameters defining the geometry of the problem and loading:**

|   Parameter   | Description                                                  | Default value |
| :-----------: | ------------------------------------------------------------ | :-----------: |
|   `MESHDIM`   | Dimension of the problem:<br />`0` = spring-block model<br />`1` = 1D fault in a 2D elastic medium, antiplane slip<br />`2` = 2D fault in a 3D elastic medium |      `0`      |
| `FAULT_TYPE`  | Faulting type (only used if `MESHDIM=2`):<br />`1` = strike-slip (right-lateral)<br />`-1` = strike-slip (left-lateral)<br />`2` = thrust<br />`-2` = normal |      `1`      |
|   `SOLVER`    | ODE solver mode:<br />`1` = Bulirsch-Stoer<br />`2` = Runge-Kutta-Fehlberg |      `1`      |
|     `MU`      | Shear modulus (Pa)                                           |    `30e9`     |
|     `LAM`     | Elastic modulus lambda for 3D simulations (Pa)               |    `30e9`     |
|     `VS`      | Shear wave speed (m/s). If `VS=0`, radiation damping is turned off |    `3000`     |
|    `V_PL`     | Plastic loading velocity (e.g. plate velocity; m/s)          |    `1e-9`     |
|      `D`      | Damage level = $1 - \frac{\mathrm{damaged~shear~modulus}}{\mathrm{intact~shear~modulus}}$<br /><br />This feature is currently implemented only for `MESHDIM = 1` and `FINITE = 0` |      `0`      |
|     `HD`      | If `D > 0`, half-thickness of the fault damage zone (m)<br />If `D = 0`, half-thickness of an elastic slab bisected by a fault<br /><br />This feature is currently implemented only for `MESHDIM = 1` and `FINITE = 0` |      `0`      |
|      `L`      | If `MESHDIM = 1`, `L` is the fault length (or spatial period; m)<br />If `MESHDIM = 0`, `MU/L` is the spring stiffness |      `1`      |
|   `FINITE`    | Boundary conditions when `MESHDIM=1`:<br />`0` = **Periodic fault**: the fault is infinitely long, but slip is spatially periodic with period `L`, loaded by steady displacement at distance `W` from the fault.<br />`1` = **Finite fault**: the fault is infinitely long, but only a segment of length `L` is explicitly governed by a [friction law](model_assumptions.html#fault-rheology). The remainder of the fault has steady slip at a rate `V_PL`. If running the code with this option gives the error message `kernel file src/kernel_I.tab is too short`, you should create a larger kernel file with the MATLAB function `TabKernelFiniteFit.m`.<br />`2` = **Symmetric periodic fault**: like option `0`, but slip is symmetric relative to the first element.<br />`3` = **Symmetric finite fault**: like option `1`, but slip is symmetric relative to the first element. This can be used to simulate a free surface adjacent to the first element. |      `1`      |
|      `W`      | Out-of-plane seismogenic width of the fault, only if `MESHDIM=1` and `FINITE=0`. **Note** that the model framework assumes that `W >> L`. |      `1`      |
|    `DIP_W`    | Distance between the fault and the loading point (m). This parameter is only used when `MESHDIM=2` or `4`. If depth-dependent, values must be given from deeper to shallower depth. |      `0`      |
|  `Z_CORNER`   | Fault bottom depth (m; negative down)                        |      `0`      |
| `SIGMA_COUPL` | Turn on or off normal stress coupling:<br />`0` = disabled<br />`1` = enabled<br />This parameter is **deprecated** for the Python wrapper, use `FEAT_STRESS_COUPL` instead (see below). |      `0`      |
|    `APER`     | Amplitude of additional time-dependent oscillatory shear stress loading (Pa) |      `0`      |
|    `TPER`     | Period of oscillatory loading (s)                            |      `0`      |

**Simulation features (only available via the Python wrapper)**:

QDYN offers various optional simulation features. Set the following parameters to 1 to enable, or 0 to disable (default).

|      Parameter      | Description                                                  |
| :-----------------: | ------------------------------------------------------------ |
| `FEAT_LOCALISATION` | Localisation of shear strain within the simulated gouge (CNS model only) |
| `FEAT_STRESS_COUPL` | Normal stress coupling                                       |
|      `FEAT_TP`      | Thermal pressurization (dynamic weakening)                   |



**Rate-and-state friction (RSF) parameters:**

**Note** that with the Python wrapper, the rheological parameters below are set in a dictionary `SET_DICT_RSF` nested within `set_dict`.

|  Parameter  | Description                                                  | Default value |
| :---------: | ------------------------------------------------------------ | :-----------: |
|     `A`     | Direct effect coefficient ($a$)                              |   `0.0010`    |
|     `B`     | Evolution effect coefficient ($b$)                           |   `0.0011`    |
|    `DC`     | Characteristic slip distance ($D_c$; m)                      |    `1e-5`     |
|   `MU_SS`   | Reference steady-state friction coefficient ($\mu^*$)        |     `0.6`     |
|   `V_SS`    | Reference steady-state slip velocity ($V^*$; m/s)            |    `1e-6`     |
|  `RNS_LAW`  | Type of rate-and-state friction law (see [Model assumptions](model_assumptions.html#fault-rheology)):<br />`0` = original formulation<br />`1` = with cut-off velocities `V1` and `V2`<br />`2` = regularized form |      `0`      |
|    `V0`     | Fault slip velocity at the start of the simulation (m/s)     |   `1.01e-5`   |
|    `V1`     | Cut-off velocity of direct effect ($V_1$; m/s)               |    `0.01`     |
|    `V2`     | Cut-off velocity of evolution effect ($V_2$; m/s) which controls the transition from velocity-weakening to -strengthening when `A < B`. `V2` should be `<= V1`. |    `1e-7`     |
| `THETA_LAW` | Type of evolution law for the state variable:<br />`0` = ageing law under the "no-healing" approximation<br />`1` = ageing law<br />`2` = slip law |      `1`      |

***Chen-Niemeijer-Spiers* (CNS) model parameters (only available via the Python wrapper):**

**Note** that with the Python wrapper, the rheological parameters below are set in a dictionary `SET_DICT_CNS` nested within `set_dict`.

|    Parameter    | Description                                                  | Default value |
| :-------------: | ------------------------------------------------------------ | :-----------: |
|   `THICKNESS`   | Total width of the gouge zone (m)                            |    `1e-3`     |
|    `A_TILDE`    | Coefficient of logarithmic rate-dependence of grain-boundary friction (-) |    `1e-3`     |
| `MU_TILDE_STAR` | Reference grain-boundary friction at `Y_GR_STAR` (-)         |    `1e-3`     |
|   `Y_GR_STAR`   | Reference strain rate corresponding with `MU_TILDE_STAR` (1/s) |    `1e-3`     |
|       `H`       | Dilatancy geometric factor (-)                               |    `1e-3`     |
|     `PHI_C`     | Critical state porosity (-)                                  |    `1e-3`     |
|     `PHI0`      | Lower cut-off porosity (e.g. percolation threshold; -)       |    `1e-3`     |
|       `A`       | List of kinetic parameters for each creep mechanism. These are passed to `set_dict` as a list or NumPy array following the format `[A1, A2, A3, ...]` |    `[0.0]`    |
|       `N`       | List of stress exponents for each creep mechanism. These are passed to `set_dict` as a list or NumPy array following the format `[N1, N2, N3, ...]` |    `[1.0]`    |
|       `M`       | List of porosity exponents for each creep mechanism. These are passed to `set_dict` as a list or NumPy array following the format `[M1, M2, M3, ...]` |    `[2.0]`    |



**Thermal pressurisation model parameters (only available via Python wrapper):**

**Note** that with the Python wrapper, the rheological parameters below are set in a dictionary `SET_DICT_TP` nested within `set_dict`.

|    Parameter    | Description                                                  | Default value |
| :-------------: | ------------------------------------------------------------ | :-----------: |
|     `HALFW`     | Half-width of the fault zone (m). If the CNS model is used, this value will be set to half the width of the gouge layer (`THICKNESS`) |   `0.5e-3`    |
|     `RHOC`      | Mean density times specific heat capacity of the medium (J/k/m3). This reflects a weighted average of the solid and fluid phases. |    `2.1e6`    |
|     `BETA`      | Bulk compressibility (pores + fluid) (1/Pa)                  |    `2e-9`     |
|      `ETA`      | Fluid dynamic viscosity (Pa s)                               |    `2e-4`     |
|      `LAM`      | Net thermal expansion coefficient (fluid - solid) (1/K)      |   `2.78e-4`   |
|      `K_T`      | Thermal conductivity (J/s/K/m)                               |     `2.0`     |
|      `K_P`      | Intrinsic hydraulic permeability (m2)                        |    `1e-16`    |
|      `P_A`      | Ambient fluid pressure (Pa)                                  |     `0.0`     |
|      `T_A`      | Ambient temperature (K)                                      |    `293.0`    |
| `DILATE_FACTOR` | Coefficient to control the efficiency of dilatancy hardening (-). Set to zero to disable dilatancy hardening effects. |     `0.0`     |

**Initial conditions:**

| Parameter | Description                                                  |
| :-------: | ------------------------------------------------------------ |
|  `SIGMA`  | Initial effective normal stress (Pa). Remains constant unless `FEAT_STRESS_CPL = 1` or `FEAT_TP = 1` |
|   `V_0`   | RSF only: initial slip velocity (m/s)                        |
|  `TH_0`   | RSF only: initial state (s)                                  |
|   `TAU`   | CNS model only: initial shear stress (Pa)                    |
| `PHI_INI` | CNS model only: initial gouge porosity (-)                   |

**Discretization and accuracy parameters:**



| Parameter | Description                                                  | Default value |
| :-------: | ------------------------------------------------------------ | :-----------: |
|    `N`    | Number of fault elements if `MESHDIM=1`. It must be a power of 2. |     `-1`      |
|   `NX`    | Number of fault elements along strike if `MESHDIM=2`. It must be a power of 2 if FFT is used along strike (`FFT_TYPE=1` or `2` in `constants.f90`) |      `1`      |
|   `NW`    | Number of fault elements along dip if `MESHDIM=2`. It must be a power of 2 if FFT is used along dip (`FFT_TYPE=2`) |     `-1`      |
| `NPROCS`  | Number of processors if running in parallel and with MPI (only implemented for `MESHDIM=2` and `FFT_TYPE=1`) |      `1`      |
|   `DW`    | Along-dip length (m) of each element, from deep to shallow   |      `1`      |
|  `TMAX`   | Threshold for stopping criterion:<br />Final simulation time (s) when `NSTOP=0`<br />Slip velocity threshold (m/s) when `NSTOP=3` |               |
|  `NSTOP`  | Stopping criterion:<br />`0` = Stop at `t = TMAX`<br />`1` = Stop at end of slip localization phase<br />`2` = Stop soon after first slip rate peak<br />`3` = Stop when slip velocity exceeds `TMAX` (m/s) |      `0`      |
|  `DTTRY`  | First trial timestep (s)                                     |    `1e-1`     |
|  `DTMAX`  | Maximum timestep (s). Set `DTMAX = 0` for unrestricted time-marching |      `0`      |
|   `ACC`   | Solver accuracy (relative tolerance)                         |    `1e-7`     |

**Output control parameters:**

|  Parameter   | Description                                                  | Default value |
| :----------: | ------------------------------------------------------------ | :-----------: |
|   `OX_SEQ`   | Type of snapshot outputs:<br />`0` = All snapshots in a single output file (`fort.19`)<br />`1`  = One output file per snapshot (`fort.1001, ...`) |      `0`      |
|   `NXOUT`    | Spatial interval for snapshot output (in number of elements) |      `1`      |
|   `NTOUT`    | Temporal interval (in number of time steps) for snapshot output |      `1`      |
|  `NTOUT_OT`  | Temporal interval (in number of time steps) for time series output |      `1`      |
|   `OX_DYN`   | Output specific snapshots of dynamic events defined by thresholds on peak slip velocity `DYN_TH_ON` and `DYN_TH_OFF` (see below):<br />`0` = Disable<br />`1` = Enable outputs for event `i`: event start = `fort.19998+3i`; event end = `fort.19999+3i`; rupture time = `fort.20000+3i` |      `0`      |
| `NXOUT_DYN`  | Spatial interval (in number of elements) for dynamic snapshot output |      `1`      |
| `DYN_TH_ON`  | Peak slip rate threshold (m/s) to define the beginning of a dynamic event |    `1e-2`     |
| `DYN_TH_OFF` | Peak slip rate threshold (m/s) to define the end of a dynamic event. It is recommended to have `DYN_TH_ON >> DYN_TH_OFF`, so that small fluctuations in slip rate during the main event do not "trigger" new events. |    `1e-4`     |
|     `IC`     | Index of selected element for time series output             |      `0`      |
|    `IOT`     | Indices of elements for additional time series output. This is a vector of length $N$ (with $N$ being the number of fault elements) with default values set to zero. To enable time series output for element `i`, set `IOT(i) = 1` (MATLAB) or `set_dict["IOT"][i] = 1` (Python). Each element has a separate output file named `fort.xxxxx`, where `xxxxx` is an index (different from `i`) that starts at `10001` and is incremented by 1 for each selected element. For instance, if `IOT = [0, 0, 1, 1]`, the output of elements `i = 3` and `i = 4` are in files `fort.10001` and `fort.10002`, respectively. |      `0`      |
|    `IASP`    | Auxiliary flags for elements. This will not affect output, but is for identification purposes only (e.g. one can set elements of a particular region to `-1` and another region to `1`). |      `0`      |

**Parameters for integration with dynamic code:**

| Parameter  | Description                                                  | Default value |
| :--------: | ------------------------------------------------------------ | :-----------: |
| `DYN_FLAG` | Integration with dynamic code:<br />`0` = Disable<br />`1` = Enable: stop QDYN at the `DYN_SKIP+1`-th event with seismic moment larger than `DYN_M` |      `0`      |
|  `DYN_M`   | Target seismic moment of a dynamic event                     |    `1e18`     |
| `DYN_SKIP` | Number of events to skip (warm-up cycles)                    |      `0`      |



## Simulation output structure

**Time-series output** (`ot`)

|   MATLAB    |    Python    | Description                                                  |
| :---------: | :----------: | ------------------------------------------------------------ |
|     `t`     |     `t`      | Simulation time (s)                                          |
|   `locl`    |  `loc_size`  | Localization length (distance between stressing rate maxima; m) |
|    `cl`     | `crack_size` | Crack length (distance between slip rate maxima; m)          |
|     `p`     |   `potcy`    | Seismic potency                                              |
|   `pdot`    |  `pot_rate`  | Seismic potency rate                                         |
|    `vc`     |     `v`      | Slip rate at `IC`                                            |
|    `thc`    |   `theta`    | State at `IC`. For RSF simulations, this is the state parameter $\theta$, for CNS simulations this is porosity. |
|    `omc`    | `v_theta_dc` | $\frac{V \theta}{D_c}$ at `IC`                               |
|   `tauc`    |    `tau`     | Shear stress (Pa) at `IC`                                    |
|    `dc`     |     `x`      | Slip at `IC`                                                 |
|     `x`     |  `pos_max`   | Location of maximum slip rate                                |
|     `v`     |   `v_max`    | Maximum slip rate                                            |
|    `th`     | `theta_max`  | State at location of maximum slip rate                       |
|    `om`     |  `omeg_max`  | $\frac{V \theta}{D_c}$ at location of maximum slip rate      |
|    `tau`    |  `tau_max`   | Shear stress at location of maximum slip rate                |
|     `d`     |   `x_max`    | Slip at location of maximum slip rate                        |
| `sigma_max` | `sigma_max`  | Normal stress at location of maximum slip rate               |
|     `P`     |     `P`      | Fluid pressure at `IC` (only for `FEAT_TP = 1`)              |
|     `T`     |     `T`      | Temperature at `IC` (only for `FEAT_TP = 1`)                 |
|   `P_max`   |   `P_max`    | Fluid pressure at location of maximum slip rate (only for `FEAT_TP = 1`) |
|   `T_max`   |   `T_max`    | Temperature at location of maximum slip rate (only for `FEAT_TP = 1`) |

**Snapshot output** (`ox`)

| MATLAB  |  Python   | Description                                                  |
| :-----: | :-------: | ------------------------------------------------------------ |
|   `x`   |    `x`    | Fault coordinates (m)                                        |
|   `t`   |    `t`    | Simulation time (t)                                          |
|   `v`   |    `v`    | Slip rate (m/s)                                              |
|  `th`   |  `theta`  | State variable. or RSF simulations, this is the state parameter $\theta$ (s), for CNS simulations this is porosity (-). |
| `dtau`  |  `dtau`   | Shear stress (Pa)                                            |
| `dtaud` | `tau_dot` | Shear stress rate (Pa/s)                                     |
|   `d`   |  `slip`   | Slip (m)                                                     |
| `sigma` |  `sigma`  | Effective normal stress. If `FEAT_TP = 1`, it is total normal stress |
|   `P`   |    `P`    | Fluid pressure (only for `FEAT_TP = 1`)                      |
|   `T`   |    `T`    | Temperature (only for `FEAT_TP = 1`)                         |



## Examples

There are a number of examples provided in the `/examples` directory.