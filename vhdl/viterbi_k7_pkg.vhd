-- Package for the clean-room (171,133) octal, K=7, rate 1/2 Viterbi decoder.
-- This is the IEEE 802.11a/g/n mandated convolutional code. Trellis table
-- below is auto-generated from golden_reference.py (gen_trellis_vhdl.py),
-- which was independently self-checked against the KU Leuven thesis's own
-- worked example before being trusted to generate this table.
--
-- No code, logic, or structure in this file or viterbi_k7_decoder.vhd is
-- derived from the Creonic GmbH / GPLv2 decoder found in the
-- BaimingZhang26213/viterbi_decoder reference repo. That repo was read only
-- to confirm its AXI4-Stream port naming convention (input/input_valid/
-- input_accept, output/output_valid/output_accept), a generic, widely used
-- interface pattern, not copied logic.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package viterbi_k7_pkg is

    constant NUM_STATES : integer := 64;

    type trellis_entry_t is record
        p0      : integer range 0 to 63;
        p1      : integer range 0 to 63;
        out0    : std_logic_vector(1 downto 0);
        out1    : std_logic_vector(1 downto 0);
        in_bit  : std_logic;
    end record;
    type trellis_table_t is array(0 to 63) of trellis_entry_t;

    constant TRELLIS : trellis_table_t := (
        0 => (p0=>0, p1=>32, out0=>"00", out1=>"11", in_bit=>'0'),
        1 => (p0=>0, p1=>32, out0=>"11", out1=>"00", in_bit=>'1'),
        2 => (p0=>1, p1=>33, out0=>"01", out1=>"10", in_bit=>'0'),
        3 => (p0=>1, p1=>33, out0=>"10", out1=>"01", in_bit=>'1'),
        4 => (p0=>2, p1=>34, out0=>"00", out1=>"11", in_bit=>'0'),
        5 => (p0=>2, p1=>34, out0=>"11", out1=>"00", in_bit=>'1'),
        6 => (p0=>3, p1=>35, out0=>"01", out1=>"10", in_bit=>'0'),
        7 => (p0=>3, p1=>35, out0=>"10", out1=>"01", in_bit=>'1'),
        8 => (p0=>4, p1=>36, out0=>"11", out1=>"00", in_bit=>'0'),
        9 => (p0=>4, p1=>36, out0=>"00", out1=>"11", in_bit=>'1'),
        10 => (p0=>5, p1=>37, out0=>"10", out1=>"01", in_bit=>'0'),
        11 => (p0=>5, p1=>37, out0=>"01", out1=>"10", in_bit=>'1'),
        12 => (p0=>6, p1=>38, out0=>"11", out1=>"00", in_bit=>'0'),
        13 => (p0=>6, p1=>38, out0=>"00", out1=>"11", in_bit=>'1'),
        14 => (p0=>7, p1=>39, out0=>"10", out1=>"01", in_bit=>'0'),
        15 => (p0=>7, p1=>39, out0=>"01", out1=>"10", in_bit=>'1'),
        16 => (p0=>8, p1=>40, out0=>"11", out1=>"00", in_bit=>'0'),
        17 => (p0=>8, p1=>40, out0=>"00", out1=>"11", in_bit=>'1'),
        18 => (p0=>9, p1=>41, out0=>"10", out1=>"01", in_bit=>'0'),
        19 => (p0=>9, p1=>41, out0=>"01", out1=>"10", in_bit=>'1'),
        20 => (p0=>10, p1=>42, out0=>"11", out1=>"00", in_bit=>'0'),
        21 => (p0=>10, p1=>42, out0=>"00", out1=>"11", in_bit=>'1'),
        22 => (p0=>11, p1=>43, out0=>"10", out1=>"01", in_bit=>'0'),
        23 => (p0=>11, p1=>43, out0=>"01", out1=>"10", in_bit=>'1'),
        24 => (p0=>12, p1=>44, out0=>"00", out1=>"11", in_bit=>'0'),
        25 => (p0=>12, p1=>44, out0=>"11", out1=>"00", in_bit=>'1'),
        26 => (p0=>13, p1=>45, out0=>"01", out1=>"10", in_bit=>'0'),
        27 => (p0=>13, p1=>45, out0=>"10", out1=>"01", in_bit=>'1'),
        28 => (p0=>14, p1=>46, out0=>"00", out1=>"11", in_bit=>'0'),
        29 => (p0=>14, p1=>46, out0=>"11", out1=>"00", in_bit=>'1'),
        30 => (p0=>15, p1=>47, out0=>"01", out1=>"10", in_bit=>'0'),
        31 => (p0=>15, p1=>47, out0=>"10", out1=>"01", in_bit=>'1'),
        32 => (p0=>16, p1=>48, out0=>"10", out1=>"01", in_bit=>'0'),
        33 => (p0=>16, p1=>48, out0=>"01", out1=>"10", in_bit=>'1'),
        34 => (p0=>17, p1=>49, out0=>"11", out1=>"00", in_bit=>'0'),
        35 => (p0=>17, p1=>49, out0=>"00", out1=>"11", in_bit=>'1'),
        36 => (p0=>18, p1=>50, out0=>"10", out1=>"01", in_bit=>'0'),
        37 => (p0=>18, p1=>50, out0=>"01", out1=>"10", in_bit=>'1'),
        38 => (p0=>19, p1=>51, out0=>"11", out1=>"00", in_bit=>'0'),
        39 => (p0=>19, p1=>51, out0=>"00", out1=>"11", in_bit=>'1'),
        40 => (p0=>20, p1=>52, out0=>"01", out1=>"10", in_bit=>'0'),
        41 => (p0=>20, p1=>52, out0=>"10", out1=>"01", in_bit=>'1'),
        42 => (p0=>21, p1=>53, out0=>"00", out1=>"11", in_bit=>'0'),
        43 => (p0=>21, p1=>53, out0=>"11", out1=>"00", in_bit=>'1'),
        44 => (p0=>22, p1=>54, out0=>"01", out1=>"10", in_bit=>'0'),
        45 => (p0=>22, p1=>54, out0=>"10", out1=>"01", in_bit=>'1'),
        46 => (p0=>23, p1=>55, out0=>"00", out1=>"11", in_bit=>'0'),
        47 => (p0=>23, p1=>55, out0=>"11", out1=>"00", in_bit=>'1'),
        48 => (p0=>24, p1=>56, out0=>"01", out1=>"10", in_bit=>'0'),
        49 => (p0=>24, p1=>56, out0=>"10", out1=>"01", in_bit=>'1'),
        50 => (p0=>25, p1=>57, out0=>"00", out1=>"11", in_bit=>'0'),
        51 => (p0=>25, p1=>57, out0=>"11", out1=>"00", in_bit=>'1'),
        52 => (p0=>26, p1=>58, out0=>"01", out1=>"10", in_bit=>'0'),
        53 => (p0=>26, p1=>58, out0=>"10", out1=>"01", in_bit=>'1'),
        54 => (p0=>27, p1=>59, out0=>"00", out1=>"11", in_bit=>'0'),
        55 => (p0=>27, p1=>59, out0=>"11", out1=>"00", in_bit=>'1'),
        56 => (p0=>28, p1=>60, out0=>"10", out1=>"01", in_bit=>'0'),
        57 => (p0=>28, p1=>60, out0=>"01", out1=>"10", in_bit=>'1'),
        58 => (p0=>29, p1=>61, out0=>"11", out1=>"00", in_bit=>'0'),
        59 => (p0=>29, p1=>61, out0=>"00", out1=>"11", in_bit=>'1'),
        60 => (p0=>30, p1=>62, out0=>"10", out1=>"01", in_bit=>'0'),
        61 => (p0=>30, p1=>62, out0=>"01", out1=>"10", in_bit=>'1'),
        62 => (p0=>31, p1=>63, out0=>"11", out1=>"00", in_bit=>'0'),
        63 => (p0=>31, p1=>63, out0=>"00", out1=>"11", in_bit=>'1')
    );

    -- Soft-decision branch distance, replacing the original hard-decision
    -- hamming2. sym is a 3-bit unsigned confidence value (0 = strongest '0',
    -- 7 = strongest '1'), matching the convention openofdm's viterbi.v
    -- wrapper expects on its sym0/sym1 ports into the Xilinx Viterbi
    -- Decoder core. erased='1' contributes zero cost (punctured position).
    function soft_cost(sym : std_logic_vector(2 downto 0); expected_bit : std_logic; erased : std_logic) return integer;

    -- sym0 pairs with out_bits(1) (the 171-octal parity) and erase(0);
    -- sym1 pairs with out_bits(0) (the 133-octal parity) and erase(1).
    -- Confirmed consistent with golden_reference.py's soft_viterbi_decode,
    -- which pairs rsyms[0]/out[0] and rsyms[1]/out[1] the same way, by the
    -- VHDL-vs-Python regression (see tb_viterbi_k7.vhd).
    function soft_branch_dist(sym0, sym1 : std_logic_vector(2 downto 0); erase : std_logic_vector(1 downto 0); out_bits : std_logic_vector(1 downto 0)) return integer;

end package viterbi_k7_pkg;

package body viterbi_k7_pkg is

    function soft_cost(sym : std_logic_vector(2 downto 0); expected_bit : std_logic; erased : std_logic) return integer is
    begin
        if erased = '1' then
            return 0;
        elsif expected_bit = '0' then
            return to_integer(unsigned(sym));
        else
            return 7 - to_integer(unsigned(sym));
        end if;
    end function;

    function soft_branch_dist(sym0, sym1 : std_logic_vector(2 downto 0); erase : std_logic_vector(1 downto 0); out_bits : std_logic_vector(1 downto 0)) return integer is
    begin
        return soft_cost(sym0, out_bits(1), erase(0)) + soft_cost(sym1, out_bits(0), erase(1));
    end function;

end package body viterbi_k7_pkg;
