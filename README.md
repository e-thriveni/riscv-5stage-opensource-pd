# RISC-V 5-Stage Pipelined Processor: Open-Source RTL-to-GDSII (SKY130)

RTL-to-GDSII flow for a 5-stage pipelined RISC-V core using open-source tools on the SkyWater SKY130 PDK.

## Flow
| Task | Description | Status |
|------|-------------|--------|
| 1 | Logic synthesis (Yosys) | Done |
| 2 | Floorplan and placement | In progress |
| 3 | Static timing analysis | Planned |

## Task 1: Synthesis
- Tool: Yosys, SKY130 standard cell library
- Top module: `top_riscv` (8 modules parsed, 2 unused modules removed by hierarchy check)
- Register file: 992 flip-flops mapped with `dfflibmap`
- Total cells: XXXX | Area: XXXX um^2 (fill from `task1_synthesis/logs/synth_stat.txt`)

Details and screenshots: [task1_synthesis](task1_synthesis/)

## Repository Layout
- `src/`: RTL (Verilog)
- `synth/`, `synth_output/`: synthesized netlists
- `task1_synthesis/`: synthesis report, netlist, screenshots
- `config.json`, `*.sdc`: flow configuration and constraints

## Credits
RTL based on the RoshXplore RISC-V pipelined processor repository. Check its license before reuse.
