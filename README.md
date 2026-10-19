# RISC-V 5-Stage Pipelined Processor: Open-Source RTL-to-GDSII (SKY130)

A 5-stage pipelined RV32I core taken through an open-source RTL-to-GDSII flow on the SkyWater SKY130 PDK. Every stage is documented with text logs and screenshots.

**Tools:** Yosys (synthesis), OpenROAD (floorplan, placement, CTS, routing), OpenSTA (timing), Magic (DRC), Netgen (LVS)

## Flow Status
| Task | Description | Status |
|------|-------------|--------|
| 1 | Logic synthesis (Yosys) | Done |
| 2 | Floorplan and placement (OpenROAD) | Done |
| 3 | Static timing analysis (OpenSTA) | Done |
| 4 | CTS, routing, antenna, DRC, LVS | In progress |

## Task 1: Synthesis
- Top module `top_riscv`: 8 modules parsed, 2 unused modules removed by the hierarchy check
- Register file: 992 flip-flops mapped with `dfflibmap`
- Total cells: 8,502 | Area: 86,192.67 um^2 | 48.89% sequential
- 493 top-level port bits, including the external memory interface and debug outputs

Details: [task1_synthesis](task1_synthesis/)

## Task 2: Floorplan and Placement
- Utilization 40% | Die 468.2 x 468.2 um | Core area 214,405.63 um^2
- 493 I/O pins placed, none without a sink
- Detailed placement legalized from 112 violations to 0 (average displacement 3.4 um, HPWL +12%)
- **Congestion:** the register file holds the most cells, but the routing-demand heatmap puts the hotspots in the data path (lower-left) and along the boundary between the data path and the register file. Instance count alone did not predict the hotspot.

Details, logs and screenshots: [task2_floorplan_placement](task2_floorplan_placement/)

## Task 3: Static Timing Analysis
STA on the synthesized netlist with an ideal clock and no wire delay, using a clock-period sweep:

| Period | Setup WNS | TNS | Hold WNS |
|--------|-----------|-----|----------|
| 40 ns | +15.41 ns | 0.00 | +0.33 ns |
| 25 ns | +0.41 ns | 0.00 | +0.33 ns |
| 24 ns | -0.59 ns | -7.06 ns | +0.33 ns |
| 20 ns | -4.59 ns | -819.77 ns | +0.33 ns |

25 ns is the first passing period among those tested. The critical paths run through the ALU. Hold slack does not change with the period.

Details and reports: [task3_sta](task3_sta/)

## Task 4: CTS, Routing and Signoff (in progress)
- **CTS:** 1,483 sinks, 197 clock buffers, clock path 4 buffers deep, 57 dummy loads
- **Post-CTS timing at 25 ns, with estimated wire parasitics:** setup WNS was -11.57 ns before repair. `repair_design` fixed 169 slew and 41 capacitance violations (153 cells resized, 215 buffers added), after which setup WNS is +10.70 ns, TNS 0, and hold +0.21 ns.
- **Power grid:** met1, met4 and met5 stripes, with power pins connected to VDD and VSS
- **Next:** detailed routing, antenna check, DRC in Magic, LVS in Netgen

## Repository Layout
- `src/`: RTL (Verilog)
- `synth/`, `synth_output/`: synthesized netlists
- `task1_synthesis/`, `task2_floorplan_placement/`, `task3_sta/`: reports, logs and screenshots for each task
- `constraint.sdc`: timing constraints
- Large database files (`.odb`) are not committed

## Credits
RTL based on the RoshXplore RISC-V pipelined processor repository. Check its license before reuse.
