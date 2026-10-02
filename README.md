# Viterbi K=7 Soft-Decision Decoder for openwifi

A clean-room VHDL Viterbi decoder (constraint length K=7, rate 1/2, IEEE 802.11
generator polynomials), packaged as a real AXI4-Stream IP and integrated with
an AXI DMA on a Zynq UltraScale+ (ZCU104), built as a drop-in replacement
target for openwifi's decode path. No HLS, no vendor IP, hand-written and
hand-verified RTL.

## Architecture

![Simplified architecture](docs/images/architecture.svg)

Three blocks wrapped as one IP (`viterbi_k7_axis`):

- **`viterbi_axis_in`** unpacks each incoming AXI4-Stream byte into `sym0`/`sym1`
  (3-bit soft confidence per coded bit) and `erase` (per-bit erasure flags for
  punctured codes), and tracks frame boundaries from `tlast`.
- **`viterbi_k7_decoder`** is the actual decoder: a 64-state Add-Compare-Select
  trellis with a tree-reduced (not linear-scan) best-state search, a
  BRAM-backed survivor memory, and a two-phase traceback.
- **`viterbi_axis_out`** serializes the decoded bits back out as bytes with
  `tlast` on the final one, and reports `streaming_busy` so the wrapper can
  hold off a new frame until the previous output has fully drained.

The whole thing talks to the PS only through a standard AXI DMA (MM2S in,
S2MM out), so it carries zero raw top-level data pins, that matters, see
"What this is not" below.

## Real, measured results

- **Verification**: a Python golden reference model (validated against a
  published K=3 textbook example before scaling to K=7) generates every test
  vector. 1000/1000 hard-decision cases pass, then 920/920 soft-decision +
  erasure cases pass bit-for-bit against the same golden model, 80 of those
  920 specifically constructed so erasure changes the correct answer, not
  just exercises the port.
- **Soft-decision gain measured, not assumed**: a real BPSK+AWGN channel
  simulation ([`measure_soft_gain.py`](measure_soft_gain.py)) shows
  soft-decision decoding needs roughly 1.7 to 2 dB less Eb/N0 than
  hard-decision for the same frame error rate.
- **Real synthesis and timing closure** on an actual ZCU104 part
  (`xczu7ev-ffvc1156-2-e`), full system including the AXI DMA and PS:
  10,230 LUTs (4.44% of the device), **WNS +0.090 ns**, TNS 0.000, 0 failing
  endpoints out of 25,475. All constraints met.

![Block design](docs/images/block_design.webp)
*PS + AXI SmartConnects + AXI DMA + `viterbi_k7_axis_0`, as implemented.*

![Waveform, full signal set](docs/images/waveform_overview.webp)
*AXI-Stream in/out, the adapter-to-core symbol signals, and both internal
state machines, from a live run of the full 920-case regression.*

![Waveform, one frame in detail](docs/images/waveform_frame_handshake_1.webp)
*A single frame's handshake zoomed in: `sym0`/`sym1`/`erase` arriving while
`input_valid` pulses, the core's `cur_state` moving IDLE &#8594; RECEIVE, and the
output adapter's own `cur_state` moving IDLE &#8594; STREAM &#8594; IDLE as it drains.*

![Waveform, a later frame, same pattern](docs/images/waveform_frame_handshake_2.webp)
*The same handshake shape recurring at frame 426/427, roughly 1000 frames
later in the run, not a one-off.*

![Waveform, decoded output](docs/images/waveform_decoded_output.webp)
*`decoded_bits`/`decode_len` on `decode_done`, cross-checked: `decode_len =
0x1f4` (500) and `num_bytes = 63 = ceil(500/8)` agree.*

## Real defects found and fixed

This is the part most write-ups leave out. In the order they were actually
hit:

1. **Golden model bit-ordering bug**: an initial single hand-check of the
   shift-register direction gave false confidence; the real bug was only
   found by an exhaustive 8-combination automated search against the full
   trellis.
2. **Reset polarity**: Vivado's clock/reset automation wired the decoder's
   active-high `rst` to an active-low `peripheral_aresetn` net. Caught by
   explicit Tcl verification of the actual driving pin, not assumed correct.
3. **`decode_len` port width**: VHDL `integer` ports are not properly sized
   by Vivado's IP-XACT packager (packaged as 32 bits regardless of real
   range), causing a real synthesis port-width mismatch. Fixed by switching
   to a fixed-width `std_logic_vector`.
4. **Catastrophic timing failure (-27.9 ns)**: the 1504x64-bit survivor
   memory wasn't inferring as block RAM, because traceback read and used it
   in the same cycle. Fixed with a two-phase fetch/use split.
5. **Second timing failure (-20.2 ns)**: the 64-way best-state search was a
   linear scan, 111 logic levels deep. Fixed with a balanced 6-level tree
   reduction.
6. **1521 I/O ports**: an earlier, raw-port version of the design could not
   be placed on real silicon at all. Fixed architecturally with the
   AXI4-Stream + DMA wrapper above.
7. **Orphaned SmartConnect**: wiring both DMA masters to the same AXI HP port
   via two separate automation calls silently created a second, disconnected
   SmartConnect. Fixed by using two distinct HP ports.

Every one of these was caught by reading real tool output (synthesis logs,
timing reports, an exhaustive search) rather than assumed fixed, and three of
them survived an initial wrong first guess before the real root cause was
found.

## What this is not

Being specific about the gap is part of the point:

- The bitstream has been generated and programmed onto a real ZCU104 over
  JTAG (`xczu7_0`), confirmed by a post-configuration hardware readback, not
  just a successful command. That proves the implementation is physically
  valid on real silicon. It does not yet prove the decoder processes real
  data correctly on that hardware: there is no bare-metal application driving
  the AXI DMA, so no test frame has actually been pushed through the design
  on the board. That is real, separate work, not a leftover step.
- No side-by-side resource or timing comparison against Xilinx's own
  `viterbi_v7_0` LogiCORE exists, it isn't licensed in this environment. The
  interface (`sym0`/`sym1`/`erase`) matches it and openofdm's production RTL
  by design, so the comparison is at least well-posed, but it hasn't been run.
- The erasure mechanism is generic and verified, but no specific 802.11
  puncture pattern (rate 2/3, 3/4) is wired up yet.

## Why this matters

The Viterbi algorithm itself is not novel, it's close to 60 years old, and
Xilinx has shipped a production decoder core for two decades. Claiming
otherwise would be the first thing a real RTL engineer would call out, so
that's not the claim here.

What this repo actually demonstrates is the full pipeline that an RTL audit
or custom-IP engagement sells: a golden reference model, exhaustive
automated verification, real synthesis and timing closure on real silicon,
and, unusually, an unfiltered log of every real defect hit along the way
instead of a curated success story. The interface and polynomials match real
production RTL on purpose, so none of the numbers above require taking
anyone's word for it.

## Repo layout

| Path | What it is |
|---|---|
| [`golden_reference.py`](golden_reference.py) | Python golden model (hard + soft decision), self-checks against a published example |
| [`gen_stimulus.py`](gen_stimulus.py) / [`gen_stimulus_soft.py`](gen_stimulus_soft.py) | Test vector generators (1000 hard-decision cases; 920 soft-decision + erasure cases) |
| [`measure_soft_gain.py`](measure_soft_gain.py) | Independent BPSK+AWGN measurement of soft-decision coding gain |
| [`vhdl/viterbi_k7_decoder.vhd`](vhdl/viterbi_k7_decoder.vhd) | The decoder core |
| [`vhdl/viterbi_k7_pkg.vhd`](vhdl/viterbi_k7_pkg.vhd) | Trellis table and branch-metric functions |
| [`vhdl/viterbi_axis_in.vhd`](vhdl/viterbi_axis_in.vhd) / [`viterbi_axis_out.vhd`](vhdl/viterbi_axis_out.vhd) | AXI4-Stream adapters |
| [`vhdl/viterbi_k7_axis.vhd`](vhdl/viterbi_k7_axis.vhd) | Top-level IP wrapper |
| [`vhdl/tb_viterbi_axis.vhd`](vhdl/tb_viterbi_axis.vhd) | AXI-Stream testbench with randomized stalls on both sides |
| [`vivado_proj/07_block_design_axis.tcl`](vivado_proj/07_block_design_axis.tcl) | Block design: PS + AXI DMA + custom IP |
| [`vivado_proj/09_impl_axis.tcl`](vivado_proj/09_impl_axis.tcl) / [`10_impl_axis_retry.tcl`](vivado_proj/10_impl_axis_retry.tcl) | Synthesis/implementation, including the retry that closed the final timing gap |

## Status

Simulation and implementation complete and passing. Bitstream generation and
on-hardware validation are the next real steps, not yet done.
