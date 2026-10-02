-- Drives viterbi_k7_axis via real AXI4-Stream handshaking (not a simplified
-- always-ready passthrough): randomized stalls on the input side (holding
-- TVALID while the DUT's TREADY is low) and on the output side (holding
-- TREADY low for random stretches while the DUT holds TVALID/TDATA stable),
-- to actually exercise the handshake logic in viterbi_axis_in/out rather
-- than just the straight-through case. Reuses stimulus.txt (same format
-- gen_stimulus_soft.py writes for the direct-port testbench).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

entity tb_viterbi_axis is
end entity tb_viterbi_axis;

architecture sim of tb_viterbi_axis is

    constant MAX_LEN    : integer := 1504;
    constant CLK_PERIOD : time := 10 ns;
    constant MAX_STR    : integer := 8192;

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal sim_running   : boolean := true;

    signal s_axis_tdata  : std_logic_vector(7 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;
    signal s_axis_tlast  : std_logic := '0';

    signal m_axis_tdata  : std_logic_vector(7 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '0';
    signal m_axis_tlast  : std_logic;

    -- Driven ONLY by rx_proc; stim_proc only reads these (a signal with no
    -- resolution function, like a plain integer or boolean, can't legally
    -- have two processes driving it -- confirmed by a real elaboration
    -- error the first time this used a boolean "done" flag set from both
    -- sides). rx_frame_count incrementing past case_i is the sync point.
    signal rx_bits        : std_logic_vector(MAX_LEN - 1 downto 0);
    signal rx_count       : integer := 0;
    signal rx_frame_count : integer := 0;

    procedure read_token(l : inout line; tok : out string; tok_len : out integer) is
        variable c    : character;
        variable good : boolean;
        variable i    : integer := 0;
    begin
        loop
            read(l, c, good);
            exit when not good or c /= ' ';
        end loop;
        while good and c /= ' ' loop
            i := i + 1;
            tok(i) := c;
            read(l, c, good);
        end loop;
        tok_len := i;
    end procedure;

    function digit_to_int(c : character) return integer is
    begin
        return character'pos(c) - character'pos('0');
    end function;

begin

    dut: entity work.viterbi_k7_axis
        generic map (MAX_FRAME_LEN => MAX_LEN)
        port map (
            clk           => clk,
            rst           => rst,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast  => s_axis_tlast,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tlast  => m_axis_tlast
        );

    clk_proc: process
    begin
        while sim_running loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Output side: random TREADY stalls, reassembles received bytes into
    -- rx_bits as they're actually handshaken (TVALID and TREADY both high).
    rx_proc: process
        variable seed1, seed2 : positive := 1;
        variable rnd          : real;
        variable byte_i       : integer := 0;
    begin
        wait until rst = '0';
        loop
            uniform(seed1, seed2, rnd);
            if rnd < 0.2 then
                m_axis_tready <= '0';
                wait until rising_edge(clk);
            else
                m_axis_tready <= '1';
                wait until rising_edge(clk);
                if m_axis_tvalid = '1' and m_axis_tready = '1' then
                    rx_bits(byte_i * 8 + 7 downto byte_i * 8) <= m_axis_tdata;
                    if m_axis_tlast = '1' then
                        rx_count       <= byte_i + 1;
                        rx_frame_count <= rx_frame_count + 1;
                        byte_i := 0;
                    else
                        byte_i := byte_i + 1;
                    end if;
                end if;
            end if;
            exit when not sim_running;
        end loop;
        wait;
    end process;

    -- Input side: drives one case at a time from stimulus.txt, with random
    -- TVALID stalls (dropping TVALID for a cycle between bytes) to test
    -- that the DUT correctly waits rather than assuming back-to-back beats.
    stim_proc: process
        file stim_file      : text open read_mode is "stimulus.txt";
        variable line_v      : line;
        variable num_cases   : integer;
        variable len_tok     : string(1 to 32);
        variable len_tok_len : integer;
        variable sym_tok     : string(1 to MAX_STR);
        variable sym_len     : integer;
        variable erase_tok   : string(1 to MAX_STR);
        variable erase_len   : integer;
        variable exp_tok     : string(1 to MAX_STR);
        variable exp_len     : integer;
        variable frame_len   : integer;
        variable pass_count  : integer := 0;
        variable fail_count  : integer := 0;
        variable mismatch    : boolean;
        variable seed1, seed2 : positive := 7;
        variable rnd          : real;
        variable byte_val     : integer;
    begin
        rst <= '1';
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD * 2;

        readline(stim_file, line_v);
        read(line_v, num_cases);

        for case_i in 1 to num_cases loop
            readline(stim_file, line_v);
            read_token(line_v, len_tok, len_tok_len);
            frame_len := integer'value(len_tok(1 to len_tok_len));
            read_token(line_v, sym_tok, sym_len);
            read_token(line_v, erase_tok, erase_len);
            read_token(line_v, exp_tok, exp_len);

            for sym in 0 to frame_len - 1 loop
                byte_val := digit_to_int(sym_tok(2 * sym + 1)) * 32
                          + digit_to_int(sym_tok(2 * sym + 2)) * 4;
                -- erase_tok(2*sym+1) is sym0's erase flag (erase(0), bit
                -- value 1); erase_tok(2*sym+2) is sym1's (erase(1), bit
                -- value 2) -- matches viterbi_axis_in's erase<=tdata(1:0)
                -- and soft_branch_dist's sym0<->erase(0)/sym1<->erase(1)
                -- pairing, same convention the already-verified direct-port
                -- testbench uses.
                if erase_tok(2 * sym + 1) = '1' then byte_val := byte_val + 1; end if;
                if erase_tok(2 * sym + 2) = '1' then byte_val := byte_val + 2; end if;

                s_axis_tdata  <= std_logic_vector(to_unsigned(byte_val, 8));
                s_axis_tvalid <= '1';
                if sym = frame_len - 1 then s_axis_tlast <= '1'; else s_axis_tlast <= '0'; end if;

                loop
                    wait until rising_edge(clk);
                    exit when s_axis_tready = '1';
                end loop;

                -- Occasionally drop TVALID for a cycle before the next beat.
                uniform(seed1, seed2, rnd);
                if rnd < 0.15 and sym /= frame_len - 1 then
                    s_axis_tvalid <= '0';
                    wait until rising_edge(clk);
                end if;
            end loop;
            s_axis_tvalid <= '0';
            s_axis_tlast  <= '0';

            wait until rx_frame_count = case_i;
            wait until rising_edge(clk);

            mismatch := false;
            if rx_count /= (frame_len + 7) / 8 then
                mismatch := true;
                report "CASE " & integer'image(case_i) & ": byte count mismatch, RTL=" &
                       integer'image(rx_count) & " expected=" & integer'image((frame_len + 7) / 8)
                       severity error;
            else
                for b in 0 to frame_len - 1 loop
                    if (rx_bits(b) = '1' and exp_tok(b + 1) /= '1') or
                       (rx_bits(b) = '0' and exp_tok(b + 1) /= '0') then
                        mismatch := true;
                    end if;
                end loop;
            end if;

            if mismatch then
                fail_count := fail_count + 1;
                report "CASE " & integer'image(case_i) & " (len=" & integer'image(frame_len) &
                       "): MISMATCH vs golden model" severity error;
            else
                pass_count := pass_count + 1;
                report "CASE " & integer'image(case_i) & " (len=" & integer'image(frame_len) &
                       "): matches golden model bit-for-bit";
            end if;
        end loop;

        report "=== AXIS TESTBENCH SUMMARY: " & integer'image(pass_count) & " / " &
               integer'image(pass_count + fail_count) & " cases matched the golden model ===";
        sim_running <= false;
        wait;
    end process;

end architecture sim;
