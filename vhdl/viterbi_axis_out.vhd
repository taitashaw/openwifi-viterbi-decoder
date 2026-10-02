-- AXI4-Stream master-side adapter for viterbi_k7_decoder. Streams
-- decoded_bits out one byte at a time, LSB-of-decoded_bits first, for
-- ceil(decode_len/8) bytes, TLAST on the final byte.
--
-- Latches decoded_bits/decode_len into its own register the cycle
-- decode_done pulses, rather than reading the core's signals live while
-- streaming. The core's decoded_bits/decode_len only stay stable until its
-- NEXT decode_done (a single-cycle-pulse convention that was fine for a
-- same-cycle consumer, but not for this multi-cycle streaming one) -- a
-- second frame could finish decoding while this adapter is still slowly
-- streaming the first one out, overwriting the core's signals mid-stream.
-- streaming_busy tells the top-level wrapper to withhold a new frame_start
-- from the core until this adapter has actually finished draining, which is
-- what makes that latch safe to rely on.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity viterbi_axis_out is
    generic (
        MAX_FRAME_LEN : integer := 1504
    );
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;

        decoded_bits   : in  std_logic_vector(MAX_FRAME_LEN - 1 downto 0);
        decode_len     : in  std_logic_vector(10 downto 0);
        decode_done    : in  std_logic;
        streaming_busy : out std_logic;

        m_axis_tdata   : out std_logic_vector(7 downto 0);
        m_axis_tvalid  : out std_logic;
        m_axis_tready  : in  std_logic;
        m_axis_tlast   : out std_logic
    );
end entity viterbi_axis_out;

architecture rtl of viterbi_axis_out is
    constant MAX_BYTES : integer := (MAX_FRAME_LEN + 7) / 8;
    type state_t is (IDLE, STREAM);
    signal cur_state : state_t := IDLE;
    signal data_reg  : std_logic_vector(MAX_FRAME_LEN - 1 downto 0) := (others => '0');
    signal num_bytes : integer range 1 to MAX_BYTES := 1;
    signal byte_idx  : integer range 0 to MAX_BYTES - 1 := 0;

    -- 'out' ports can't be read back in plain VHDL; keep the real state in
    -- these internal signals and drive the ports from them concurrently.
    signal tdata_i  : std_logic_vector(7 downto 0) := (others => '0');
    signal tvalid_i : std_logic := '0';
    signal tlast_i  : std_logic := '0';
begin
    streaming_busy <= '0' when cur_state = IDLE else '1';
    m_axis_tdata  <= tdata_i;
    m_axis_tvalid <= tvalid_i;
    m_axis_tlast  <= tlast_i;

    process(clk)
        variable len_int   : integer;
        variable nb        : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cur_state <= IDLE;
                tvalid_i  <= '0';
            else
                case cur_state is

                    when IDLE =>
                        if decode_done = '1' then
                            len_int := to_integer(unsigned(decode_len));
                            nb := (len_int + 7) / 8;
                            data_reg  <= decoded_bits;
                            num_bytes <= nb;
                            byte_idx  <= 0;
                            tdata_i   <= decoded_bits(7 downto 0);
                            tvalid_i  <= '1';
                            if nb = 1 then
                                tlast_i <= '1';
                            else
                                tlast_i <= '0';
                            end if;
                            cur_state <= STREAM;
                        else
                            tvalid_i <= '0';
                        end if;

                    when STREAM =>
                        if tvalid_i = '1' and m_axis_tready = '1' then
                            if byte_idx = num_bytes - 1 then
                                tvalid_i  <= '0';
                                cur_state <= IDLE;
                            else
                                byte_idx <= byte_idx + 1;
                                tdata_i  <= data_reg((byte_idx + 1) * 8 + 7 downto (byte_idx + 1) * 8);
                                if (byte_idx + 1) = num_bytes - 1 then
                                    tlast_i <= '1';
                                else
                                    tlast_i <= '0';
                                end if;
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process;
end architecture rtl;
