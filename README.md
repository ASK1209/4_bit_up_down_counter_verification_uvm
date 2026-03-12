# 4-Bit Up-Down Counter Verification using UVM (Universal Verification Methodology)

A complete functional verification project for a 4-bit up-down counter using a **UVM-based testbench** with constrained-random stimulus, TLM-connected components, a self-checking scoreboard, functional coverage, and SVA assertions. Simulated on **Aldec Riviera-PRO 2025.04** via EDA Playground(https://www.edaplayground.com/).

---

## Project Structure

```
├── design.sv          # RTL: 4-bit up-down counter
└── testbench.sv       # UVM Testbench (single file)
                       #   ├── Interface
                       #   ├── Sequence Item
                       #   ├── Sequence
                       #   ├── Driver
                       #   ├── Monitor
                       #   ├── Scoreboard
                       #   ├── Agent
                       #   ├── Environment
                       #   ├── Test
                       #   └── Top Module (tb)
```

---

## Design Overview

The DUT is a synchronous 4-bit up-down counter:

| Port       | Direction | Description                        |
|------------|-----------|------------------------------------|
| `clk`      | Input     | Clock signal                       |
| `rst`      | Input     | Active-high synchronous reset      |
| `enable`   | Input     | Enables counting when high         |
| `up_down`  | Input     | `1` = count up, `0` = count down   |
| `count`    | Output    | 4-bit counter output               |

**Behavior:**
- On reset: `count` resets to `0`
- `enable=1`, `up_down=1`: count increments (`count + 1`)
- `enable=1`, `up_down=0`: count decrements (`count - 1`)
- Wraps: `15 → 0` (up) and `0 → 15` (down)

---

## UVM Testbench Architecture

```
┌──────────────────────────────────────────────┐
│                  uvm_test                    │
│  ┌────────────────────────────────────────┐  │
│  │               uvm_env                  │  │
│  │                                        │  │
│  │  ┌──────────────────┐  ┌────────────┐  │  │
│  │  │    uvm_agent     │  │ Scoreboard │  │  │
│  │  │                  │  └─────▲──────┘  │  │
│  │  │  ┌────────────┐  │        │TLM      │  │
│  │  │  │ Sequencer  │  │  ┌─────┴──────┐  │  │
│  │  │  └─────┬──────┘  │  │  Monitor   │  │  │
│  │  │        │         │  └────────────┘  │  │
│  │  │  ┌─────▼──────┐  │                  │  │
│  │  │  │   Driver   │  │                  │  │
│  │  │  └────────────┘  │                  │  │
│  │  └──────────────────┘                  │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

---

## UVM Components

| Component | Class | Description |
|-----------|-------|-------------|
| **Sequence Item** | `counter_seq_item` | Transaction object with `rand enable`, `rand up_down` and constraints |
| **Sequence** | `counter_rand_seq` | Generates 500 constrained-random transactions |
| **Driver** | `counter_driver` | Fetches items from sequencer and drives the virtual interface |
| **Monitor** | `counter_monitor` | Observes DUT outputs and broadcasts via `uvm_analysis_port` |
| **Scoreboard** | `counter_scoreboard` | Reference model — compares expected vs actual count via TLM |
| **Agent** | `counter_agent` | Contains driver, monitor, and sequencer |
| **Environment** | `counter_env` | Contains agent and scoreboard, connects TLM ports |
| **Test** | `counter_test` | Starts sequence, controls objection mechanism |

---

## Constrained Randomization

```systemverilog
class counter_seq_item extends uvm_sequence_item;
    rand logic enable;
    rand logic up_down;

    // enable is ON 80% of the time
    constraint enable_dist {
        enable dist {1 := 80, 0 := 20};
    }

    // equal probability of up and down
    constraint updown_dist {
        up_down dist {1 := 50, 0 := 50};
    }
endclass
```

---

## TLM Connection (Monitor → Scoreboard)

```
Monitor                          Scoreboard
uvm_analysis_port ─────────────► uvm_analysis_imp
     mon_ap.write(tr)                 write(tr) called automatically
```

---

## Functional Coverage

| Coverpoint | Description |
|------------|-------------|
| `cp_enable` | Covers `enable = 0` and `enable = 1` |
| `cp_updown` | Covers `up_down = 0` and `up_down = 1` |
| `cp_count` | Covers all 16 states `[0:15]` |
| `bins wrap_up` | Transition: `15 → 0` |
| `bins wrap_down` | Transition: `0 → 15` |
| `cross cp_enable, cp_updown` | All combinations of enable and up_down |

---

## SVA Assertions

| Assertion | Property Verified |
|-----------|-------------------|
| `reset_check` | `count == 0` when `rst = 1` |
| `enable_check` | `count` stable when `enable = 0` |
| `count_up_check` | Count increments by 1 (non-wrap) |
| `count_down_check` | Count decrements by 1 (non-wrap) |
| `wrap_up_check` | `15 → 0` wrap when counting up |
| `wrap_down_check` | `0 → 15` wrap when counting down |

---

## Simulation Results

```
UVM_INFO  : All transactions PASS
UVM_ERROR : 0
UVM_FATAL : 0

Functional Coverage = 100.00 %
Enable  coverage    = 100.00 %
UpDown  coverage    = 100.00 %
Count   coverage    = 100.00 %

*** ALL TESTS PASSED ***
```

---

## How to Run

### On EDA Playground
1. Go to https://www.edaplayground.com/
2. Paste `design.sv` in the **Design** pane
3. Paste `testbench.sv` in the **Testbench** pane
4. Configure the left panel:

| Setting | Value |
|---------|-------|
| Language | SystemVerilog/Verilog |
| UVM/OVM | **UVM 1.2** |
| Simulator | Aldec Riviera-PRO |
| Compile Options | `-sv -uvm` |
| Run Options | `+access+r +UVM_TESTNAME=counter_test` |

5. Click **Run**

---

## Key UVM Concepts Demonstrated

| Concept | Where Used |
|---------|-----------|
| `uvm_sequence_item` | Transaction definition |
| `uvm_sequence` | Stimulus generation |
| `uvm_driver` | Interface driving |
| `uvm_monitor` | Output observation |
| `uvm_scoreboard` | Self-checking reference model |
| `uvm_agent` | Encapsulation of driver + monitor + sequencer |
| `uvm_env` | Top-level environment |
| `uvm_test` | Test control |
| `uvm_config_db` | Virtual interface passing |
| `uvm_analysis_port` | TLM monitor → scoreboard connection |
| `raise/drop_objection` | Simulation end control |
| `uvm_info / uvm_error / uvm_fatal` | Structured messaging |
| `report_phase` | End-of-test summary |
| Constrained randomization | `rand` fields + `constraint` blocks |

---

## Tools Used

| Tool | Version |
|------|---------|
| Simulator | Aldec Riviera-PRO 2025.04 |
| UVM Library | UVM 1.2 |
| Language | SystemVerilog IEEE 1800-2012 |
| Platform | EDA Playground |

---

## Related Project

This project is a UVM upgrade of an earlier SVTB-based verification of the same DUT:
- (#https://github.com/ASK1209/4_bit_up_down_counter_verification_svtb) 

---
## 👩‍💻 Author

**Ahalya S Kumar**  
Design Verification Engineer  
SystemVerilog | SVA | Functional Coverage | UVM (Learning)
