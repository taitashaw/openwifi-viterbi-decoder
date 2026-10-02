-- Clean-room block-based Viterbi decoder for the (171,133) K=7 rate-1/2 code.
-- Original design: this session, verified against golden_reference.py.
-- Port naming follows the generic AXI4-Stream convention (input_valid/
-- input_accept) seen across many independent implementations, plus
-- sym0/sym1/erase matching openofdm's viterbi.v wrapper; no logic here is
-- derived from any third-party decoder.
--
-- Architecture: accumulate 64-state path metrics and per-state survivor bits
-- for one full frame (register-array storage, sized by MAX_FRAME_LEN), then
-- trace back from the minimum-metric final state once frame_end arrives.
-- Appropriate for 802.11's discrete-frame structure; not a sliding-window
-- streaming design (that would be a later optimization for very long frames).
--
-- Traceback reads survivor_mem through a one-cycle fetch/use split (TB_FETCH
-- then TB_USE per bit, so traceback takes 2x frame_len cycles instead of 1x)
-- rather than a same-cycle combinational read. A first synthesis run proved
-- this matters, not just style: same-cycle read+use left no way for Vivado
-- to infer survivor_mem as Block RAM, so it built 1504x64 flip-flops and a
-- 145-logic-level mux to read them, missing 100MHz timing by -27.9ns. The
-- one-cycle split lets the read land in a real BRAM output register.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.viterbi_k7_pkg.all;

entity viterbi_k7_decoder is
    generic (
        MAX_FRAME_LEN : integer := 1504
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;

        -- 3-bit soft-decision symbols + 2-bit erasure, matching openofdm's
        -- viterbi.v wrapper (sym0/sym1/erase into the Xilinx Viterbi
        -- Decoder core) rather than the original 1-bit-per-symbol hard
        -- decision. Real, measured gain from this change (golden_reference
        -- soft_viterbi_decode vs hard viterbi_decode, same BPSK+AWGN channel
        -- realizations): ~1.7-2dB less Eb/N0 needed for the same frame
        -- error rate, consistent with the textbook soft-decision figure.
        sym0          : in  std_logic_vector(2 downto 0);
        sym1          : in  std_logic_vector(2 downto 0);
        erase         : in  std_logic_vector(1 downto 0);
        input_valid   : in  std_logic;
        input_accept  : out std_logic;
        frame_start   : in  std_logic;
        frame_end     : in  std_logic;

        decoded_bits  : out std_logic_vector(MAX_FRAME_LEN - 1 downto 0);
        -- Fixed 11 bits (covers 0..2047) rather than tied to MAX_FRAME_LEN:
        -- an integer-typed port here synthesized at a different width than
        -- Vivado's IP-XACT packaging declared it (port width = 11, actual
        -- width = 32), a real synthesis failure, not a style preference.
        -- 11 bits holds the default MAX_FRAME_LEN=1504; a future generic
        -- above 2047 would need this widened to match.
        decode_len    : out std_logic_vector(10 downto 0);
        decode_done   : out std_logic;
        busy          : out std_logic
    );
end entity viterbi_k7_decoder;

architecture rtl of viterbi_k7_decoder is

    type pm_array_t is array(0 to NUM_STATES - 1) of unsigned(15 downto 0);
    type idx_array_t is array(0 to NUM_STATES - 1) of integer range 0 to NUM_STATES - 1;
    type state_t is (IDLE, RECEIVE, TB_FETCH, TB_USE, DONE_ST);
    type survivor_mem_t is array(0 to MAX_FRAME_LEN - 1) of std_logic_vector(NUM_STATES - 1 downto 0);

    -- Finds the state with the minimum path metric as a balanced tree
    -- (64->32->16->8->4->2->1, 6 levels) instead of a 63-deep sequential
    -- scan. A first synthesis run proved the scan mattered, not just
    -- style: it built a 36-CARRY8, 111-logic-level chain (comparing state
    -- 1 against 0, then 2 against that winner, then 3, ... sequentially)
    -- that alone missed 100MHz by -20.2ns even after the survivor_mem fix.
    -- Hardcodes 6 levels for NUM_STATES=64 specifically, matching the rest
    -- of this file's K=7/64-state-specific (non-generic) logic.
    function find_best_state(pm : pm_array_t) return integer is
        variable val  : pm_array_t := pm;
        variable idx  : idx_array_t;
        variable span : integer;
    begin
        for s in 0 to NUM_STATES - 1 loop
            idx(s) := s;
        end loop;
        span := NUM_STATES;
        for level in 0 to 5 loop
            span := span / 2;
            for i in 0 to span - 1 loop
                if val(2 * i + 1) < val(2 * i) then
                    val(i) := val(2 * i + 1);
                    idx(i) := idx(2 * i + 1);
                else
                    val(i) := val(2 * i);
                    idx(i) := idx(2 * i);
                end if;
            end loop;
        end loop;
        return idx(0);
    end function;

    -- Sentinel for "not yet reached". Must be far enough below the field's
    -- true max that adding a real branch metric (0..2 per cycle) never wraps
    -- around during the handful of early cycles before a state is reached,
    -- while staying far above any real accumulated metric (<=2 per bit, so
    -- <=3000 over the longest supported 1500-bit frame).
    constant PM_MAX : unsigned(15 downto 0) := to_unsigned(60000, 16);

    signal cur_state    : state_t := IDLE;
    signal path_metric  : pm_array_t;
    signal survivor_mem : survivor_mem_t;
    signal time_idx     : integer range 0 to MAX_FRAME_LEN - 1 := 0;
    signal frame_len_r  : integer range 0 to MAX_FRAME_LEN := 0;
    signal tb_idx       : integer range 0 to MAX_FRAME_LEN - 1 := 0;
    signal tb_state     : integer range 0 to NUM_STATES - 1 := 0;
    signal survivor_word : std_logic_vector(NUM_STATES - 1 downto 0);
    signal decoded_reg  : std_logic_vector(MAX_FRAME_LEN - 1 downto 0) := (others => '0');

begin

    process(clk)
        variable pm_in    : pm_array_t;
        variable new_pm   : pm_array_t;
        variable new_surv : std_logic_vector(NUM_STATES - 1 downto 0);
        variable cand0, cand1 : unsigned(15 downto 0);
        variable best_s   : integer range 0 to NUM_STATES - 1;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cur_state    <= IDLE;
                input_accept <= '1';
                busy         <= '0';
                decode_done  <= '0';
                time_idx     <= 0;
            else
                decode_done <= '0';

                case cur_state is

                    when IDLE =>
                        input_accept <= '1';
                        busy <= '0';

                        if input_valid = '1' and frame_start = '1' then
                            busy <= '1';

                            for s in 0 to NUM_STATES - 1 loop
                                if s = 0 then
                                    pm_in(s) := (others => '0');
                                else
                                    pm_in(s) := PM_MAX;
                                end if;
                            end loop;

                            for s in 0 to NUM_STATES - 1 loop
                                cand0 := pm_in(TRELLIS(s).p0) + to_unsigned(soft_branch_dist(sym0, sym1, erase, TRELLIS(s).out0), 16);
                                cand1 := pm_in(TRELLIS(s).p1) + to_unsigned(soft_branch_dist(sym0, sym1, erase, TRELLIS(s).out1), 16);
                                if cand0 <= cand1 then
                                    new_pm(s) := cand0; new_surv(s) := '0';
                                else
                                    new_pm(s) := cand1; new_surv(s) := '1';
                                end if;
                            end loop;
                            survivor_mem(time_idx) <= new_surv;
                            path_metric <= new_pm;

                            if frame_end = '1' then
                                best_s := find_best_state(new_pm);
                                frame_len_r  <= 1;
                                tb_idx       <= 0;
                                tb_state     <= best_s;
                                cur_state    <= TB_FETCH;
                                input_accept <= '0';
                            else
                                time_idx  <= 1;
                                cur_state <= RECEIVE;
                            end if;
                        end if;

                    when RECEIVE =>
                        input_accept <= '1';
                        if input_valid = '1' then
                            for s in 0 to NUM_STATES - 1 loop
                                cand0 := path_metric(TRELLIS(s).p0) + to_unsigned(soft_branch_dist(sym0, sym1, erase, TRELLIS(s).out0), 16);
                                cand1 := path_metric(TRELLIS(s).p1) + to_unsigned(soft_branch_dist(sym0, sym1, erase, TRELLIS(s).out1), 16);
                                if cand0 <= cand1 then
                                    new_pm(s) := cand0; new_surv(s) := '0';
                                else
                                    new_pm(s) := cand1; new_surv(s) := '1';
                                end if;
                            end loop;
                            survivor_mem(time_idx) <= new_surv;
                            path_metric <= new_pm;

                            if frame_end = '1' then
                                best_s := find_best_state(new_pm);
                                frame_len_r  <= time_idx + 1;
                                tb_idx       <= time_idx;
                                tb_state     <= best_s;
                                cur_state    <= TB_FETCH;
                                input_accept <= '0';
                            else
                                time_idx <= time_idx + 1;
                            end if;
                        end if;

                    when TB_FETCH =>
                        -- One registered read of survivor_mem(tb_idx), kept
                        -- separate from its use so the array can infer as
                        -- Block RAM (synchronous address in, data out next
                        -- cycle) instead of a same-cycle combinational read.
                        input_accept <= '0';
                        survivor_word <= survivor_mem(tb_idx);
                        cur_state <= TB_USE;

                    when TB_USE =>
                        input_accept <= '0';
                        decoded_reg(tb_idx) <= TRELLIS(tb_state).in_bit;
                        if survivor_word(tb_state) = '0' then
                            tb_state <= TRELLIS(tb_state).p0;
                        else
                            tb_state <= TRELLIS(tb_state).p1;
                        end if;

                        if tb_idx = 0 then
                            cur_state <= DONE_ST;
                        else
                            tb_idx     <= tb_idx - 1;
                            cur_state  <= TB_FETCH;
                        end if;

                    when DONE_ST =>
                        input_accept <= '0';
                        decode_done  <= '1';
                        busy         <= '0';
                        decoded_bits <= decoded_reg;
                        decode_len   <= std_logic_vector(to_unsigned(frame_len_r, 11));
                        cur_state    <= IDLE;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
