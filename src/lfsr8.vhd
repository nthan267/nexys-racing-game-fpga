

library ieee;
use ieee.std_logic_1164.all;

entity lfsr8 is
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        rand_o : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of lfsr8 is
    signal reg : std_logic_vector(7 downto 0) := x"5A";
    signal fb  : std_logic;
begin
    
    fb <= reg(7) xor reg(5) xor reg(4) xor reg(3);

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                reg <= x"5A";
            else
                reg <= reg(6 downto 0) & fb;
            end if;
        end if;
    end process;

    rand_o <= reg;
end architecture;
