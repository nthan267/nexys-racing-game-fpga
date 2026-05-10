

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debouncer is
    generic (
        STABLE_CYCLES : positive := 1_000_000  -- 10 ms @ 100 MHz
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;  
        noisy_i : in  std_logic;
        clean_o : out std_logic;
        pulse_o : out std_logic   
    );
end entity;

architecture rtl of debouncer is
    signal sync_ff1, sync_ff2 : std_logic := '0';
    signal counter : unsigned(24 downto 0) := (others => '0');
    signal clean_r, clean_prev : std_logic := '0';
begin
    
    process(clk)
    begin
        if rising_edge(clk) then
            sync_ff1 <= noisy_i;
            sync_ff2 <= sync_ff1;
        end if;
    end process;

  
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                counter    <= (others => '0');
                clean_r    <= '0';
                clean_prev <= '0';
            else
                clean_prev <= clean_r;
                if sync_ff2 /= clean_r then
                    if counter = to_unsigned(STABLE_CYCLES - 1, counter'length) then
                        clean_r <= sync_ff2;
                        counter <= (others => '0');
                    else
                        counter <= counter + 1;
                    end if;
                else
                    counter <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    clean_o <= clean_r;
    pulse_o <= '1' when (clean_r = '1' and clean_prev = '0') else '0';
end architecture;
