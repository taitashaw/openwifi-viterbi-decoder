-- AXI4-Stream slave-side adapter for viterbi_k7_decoder. One byte per
-- symbol: TDATA(7:5)=sym0, TDATA(4:2)=sym1, TDATA(1:0)=erase. Frame
-- boundaries come from TLAST alone (no separate frame_start wire on the
-- bus): the beat right after a TLAST, or the very first beat after reset,
-- is tagged frame_start for the core.
library ieee;
use ieee.std_logic_1164.all;

entity viterbi_axis_in is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;

        s_axis_tdata  : in  std_logic_vector(7 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tlast  : in  std_logic;

        sym0          : out std_logic_vector(2 downto 0);
        sym1          : out std_logic_vector(2 downto 0);
        erase         : out std_logic_vector(1 downto 0);
        input_valid   : out std_logic;
        frame_start   : out std_logic;
        frame_end     : out std_logic;
        -- Already gated by the top-level wrapper (core's own input_accept
        -- ANDed with "not streaming_busy"), not the core's raw output.
        input_accept  : in  std_logic
    );
end entity viterbi_axis_in;

architecture rtl of viterbi_axis_in is
    signal expect_start : std_logic := '1';
begin
    sym0  <= s_axis_tdata(7 downto 5);
    sym1  <= s_axis_tdata(4 downto 2);
    erase <= s_axis_tdata(1 downto 0);
    frame_end     <= s_axis_tlast;
    frame_start   <= expect_start;
    s_axis_tready <= input_accept;

    -- Only ever assert input_valid to the core on a cycle where we've also
    -- asserted ready to the bus. The core has no genuine mid-frame stall of
    -- its own (input_accept is a static "I'm receiving" flag, not a real
    -- backpressure signal), so a bare passthrough of s_axis_tvalid would let
    -- it wrongly consume a held TVALID during a cycle we're stalling (e.g.
    -- the frame-boundary gate while the previous frame's output drains).
    input_valid <= s_axis_tvalid and input_accept;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                expect_start <= '1';
            elsif s_axis_tvalid = '1' and input_accept = '1' then
                expect_start <= s_axis_tlast;
            end if;
        end if;
    end process;
end architecture rtl;
