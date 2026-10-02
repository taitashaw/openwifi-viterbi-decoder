-- Top-level AXI4-Stream wrapper around the clean-room viterbi_k7_decoder
-- core (unchanged internally) plus viterbi_axis_in/viterbi_axis_out. This
-- is the IP meant for real integration: a standard AXI4-Stream slave in,
-- AXI4-Stream master out, suitable for direct connection to an AXI DMA in
-- Vivado instead of raw internal ports brought out to the top level (which
-- a prior block design proved cannot map to real silicon pins at all --
-- 1504 raw decoded_bits pins alone blew past any real package's I/O count).
library ieee;
use ieee.std_logic_1164.all;

entity viterbi_k7_axis is
    generic (
        MAX_FRAME_LEN : integer := 1504
    );
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;

        s_axis_tdata  : in  std_logic_vector(7 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tlast  : in  std_logic;

        m_axis_tdata  : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tlast  : out std_logic
    );
end entity viterbi_k7_axis;

architecture struct of viterbi_k7_axis is
    signal sym0, sym1               : std_logic_vector(2 downto 0);
    signal erase                    : std_logic_vector(1 downto 0);
    signal input_valid, input_accept : std_logic;
    signal frame_start, frame_end   : std_logic;
    signal decoded_bits             : std_logic_vector(MAX_FRAME_LEN - 1 downto 0);
    signal decode_len               : std_logic_vector(10 downto 0);
    signal decode_done, busy        : std_logic;
    signal streaming_busy           : std_logic;
    signal input_accept_gated       : std_logic;
begin
    -- See viterbi_axis_out.vhd: withhold a new frame_start from the core
    -- until the previous frame's output has actually finished draining.
    input_accept_gated <= input_accept and not streaming_busy;

    u_in : entity work.viterbi_axis_in
        port map (
            clk           => clk,
            rst           => rst,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast  => s_axis_tlast,
            sym0          => sym0,
            sym1          => sym1,
            erase         => erase,
            input_valid   => input_valid,
            frame_start   => frame_start,
            frame_end     => frame_end,
            input_accept  => input_accept_gated
        );

    u_core : entity work.viterbi_k7_decoder
        generic map (MAX_FRAME_LEN => MAX_FRAME_LEN)
        port map (
            clk          => clk,
            rst          => rst,
            sym0         => sym0,
            sym1         => sym1,
            erase        => erase,
            input_valid  => input_valid,
            input_accept => input_accept,
            frame_start  => frame_start,
            frame_end    => frame_end,
            decoded_bits => decoded_bits,
            decode_len   => decode_len,
            decode_done  => decode_done,
            busy         => busy
        );

    u_out : entity work.viterbi_axis_out
        generic map (MAX_FRAME_LEN => MAX_FRAME_LEN)
        port map (
            clk            => clk,
            rst            => rst,
            decoded_bits   => decoded_bits,
            decode_len     => decode_len,
            decode_done    => decode_done,
            streaming_busy => streaming_busy,
            m_axis_tdata   => m_axis_tdata,
            m_axis_tvalid  => m_axis_tvalid,
            m_axis_tready  => m_axis_tready,
            m_axis_tlast   => m_axis_tlast
        );
end architecture struct;
