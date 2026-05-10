

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider is
    generic (
        DIV_MAX : positive := 100_000_000  -- 100 MHz / 1 Hz
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        tick_o : out std_logic
    );
end entity;

architecture rtl of clock_divider is
    signal cnt : unsigned(26 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cnt    <= (others => '0');
                tick_o <= '0';
            elsif cnt = to_unsigned(DIV_MAX - 1, cnt'length) then
                cnt    <= (others => '0');
                tick_o <= '1';
            else
                cnt    <= cnt + 1;
                tick_o <= '0';
            end if;
        end if;
    end process;
end architecture;
