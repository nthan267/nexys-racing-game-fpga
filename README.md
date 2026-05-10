
# Red Light, Green Light

A four-player racing game on FPGA. Advance during Green Light, get eliminated if you move during Red Light. First to 12 meters wins, or last player remaining if time runs out. Built on a Xilinx Nexys A7 board with real-time display and button controls.

**For full design details, specifications, testbench results, and synthesis analysis, see [COEN313_RedLightGreenLight_Report.pdf](./docs/COEN313_RedLightGreenLight_Report.pdf).**

**Video demonstration available in the doc folder.**

## Quick Start

### Build with Vivado

```bash
vivado -mode batch -source build.tcl
```

Targets XC7A100T. Add source files from `src/`, constraints from `constraints/nexys_a7.xdc`, run synthesis and place-and-route.

### Simulate with ModelSim

```bash
cd sim
do run_sim.do
```

Runs self-checking VHDL testbench covering five game scenarios. All assertions pass.

## File Structure

```
.
├── src/                 # VHDL source files
│   ├── red_light_green_light.vhd  # Top level
│   ├── game_fsm.vhd
│   ├── player_unit.vhd
│   ├── debouncer.vhd
│   ├── clock_divider.vhd
│   ├── lfsr8.vhd        # Bonus: on-chip randomness
│   └── seg7_*.vhd       # Display logic
├── sim/
│   ├── tb_red_light_green_light.vhd
│   └── run_sim.do
├── constraints/
│   └── nexys_a7.xdc
└── docs/
    └── COEN313_RedLightGreenLight_Report.pdf
```

## Hardware

- **Target**: Xilinx Artix-7 XC7A100T-1CSG324C (Nexys A7-100T)
- **Clock**: 100 MHz
- **Resources**: ~220 LUTs, ~140 registers (< 0.4% utilization)

## Design Highlights

- Single clock domain with synchronous 1 Hz enable strobe
- Four-state FSM (IDLE → GREEN → RED → DONE)
- Time-multiplexed 8-digit display at ~760 Hz per digit
- Deterministic tie-breaking; winner detection prioritized over timer expiry
- On-chip LFSR for bonus bounded randomness challenge
- Comprehensive testbench with 100% scenario coverage
 
COEN 313 — Digital Systems Design  
Winter 2026

## License

Educational purposes. See LICENSE for details.
