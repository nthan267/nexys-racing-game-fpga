

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity seg7_decoder is
    port (
        nibble_i : in  std_logic_vector(3 downto 0);
        blank_i  : in  std_logic;  -- if '1', output all segments off
        dash_i   : in  std_logic;  -- if '1', output only middle segment (g)
        seg_o    : out std_logic_vector(6 downto 0)  -- {a,b,c,d,e,f,g}, active low
    );
end entity;

architecture rtl of seg7_decoder is
begin
    process(nibble_i, blank_i, dash_i)
    begin
        if blank_i = '1' then
            seg_o <= "1111111";
        elsif dash_i = '1' then
            seg_o <= "1111110";  -- only 'g' lit
        else
            case nibble_i is
                when x"0" => seg_o <= "0000001";
                when x"1" => seg_o <= "1001111";
                when x"2" => seg_o <= "0010010";
                when x"3" => seg_o <= "0000110";
                when x"4" => seg_o <= "1001100";
                when x"5" => seg_o <= "0100100";
                when x"6" => seg_o <= "0100000";
                when x"7" => seg_o <= "0001111";
                when x"8" => seg_o <= "0000000";
                when x"9" => seg_o <= "0000100";
                when x"A" => seg_o <= "0001000";
                when x"B" => seg_o <= "1100000";
                when x"C" => seg_o <= "0110001";
                when x"D" => seg_o <= "1000010";
                when x"E" => seg_o <= "0110000";
                when x"F" => seg_o <= "0111000";
                when others => seg_o <= "1111111";
            end case;
        end if;
    end process;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_mux is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        -- 8 digit payloads, one nibble each
        digits_i  : in  std_logic_vector(31 downto 0);  -- {d7,d6,d5,d4,d3,d2,d1,d0}
        blank_i   : in  std_logic_vector(7 downto 0);   -- per-digit blank
        dash_i    : in  std_logic_vector(7 downto 0);   -- per-digit dash
        -- Nexys A7 outputs
        an_o      : out std_logic_vector(7 downto 0);
        seg_o     : out std_logic_vector(6 downto 0)
    );
end entity;

architecture rtl of display_mux is
    signal refresh_cnt : unsigned(19 downto 0) := (others => '0');
    signal sel         : unsigned(2 downto 0);
    signal nibble      : std_logic_vector(3 downto 0);
    signal blank_sel   : std_logic;
    signal dash_sel    : std_logic;
    signal seg_raw     : std_logic_vector(6 downto 0);

    component seg7_decoder is
        port (
            nibble_i : in  std_logic_vector(3 downto 0);
            blank_i  : in  std_logic;
            dash_i   : in  std_logic;
            seg_o    : out std_logic_vector(6 downto 0)
        );
    end component;
begin

    sel <= refresh_cnt(19 downto 17);

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                refresh_cnt <= (others => '0');
            else
                refresh_cnt <= refresh_cnt + 1;
            end if;
        end if;
    end process;

   
    process(sel, digits_i, blank_i, dash_i)
    begin
        case sel is
            when "000" => nibble <= digits_i(3  downto 0);   blank_sel <= blank_i(0); dash_sel <= dash_i(0);
            when "001" => nibble <= digits_i(7  downto 4);   blank_sel <= blank_i(1); dash_sel <= dash_i(1);
            when "010" => nibble <= digits_i(11 downto 8);   blank_sel <= blank_i(2); dash_sel <= dash_i(2);
            when "011" => nibble <= digits_i(15 downto 12);  blank_sel <= blank_i(3); dash_sel <= dash_i(3);
            when "100" => nibble <= digits_i(19 downto 16);  blank_sel <= blank_i(4); dash_sel <= dash_i(4);
            when "101" => nibble <= digits_i(23 downto 20);  blank_sel <= blank_i(5); dash_sel <= dash_i(5);
            when "110" => nibble <= digits_i(27 downto 24);  blank_sel <= blank_i(6); dash_sel <= dash_i(6);
            when others=> nibble <= digits_i(31 downto 28);  blank_sel <= blank_i(7); dash_sel <= dash_i(7);
        end case;
    end process;

    U_DEC: seg7_decoder
        port map (
            nibble_i => nibble,
            blank_i  => blank_sel,
            dash_i   => dash_sel,
            seg_o    => seg_raw
        );

 
    process(sel)
    begin
        case sel is
            when "000" => an_o <= "11111110";
            when "001" => an_o <= "11111101";
            when "010" => an_o <= "11111011";
            when "011" => an_o <= "11110111";
            when "100" => an_o <= "11101111";
            when "101" => an_o <= "11011111";
            when "110" => an_o <= "10111111";
            when others=> an_o <= "01111111";
        end case;
    end process;

    seg_o <= seg_raw;
end architecture;
