
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity player_unit is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        tick_i          : in  std_logic;  -- 1 Hz enable
        is_green_i      : in  std_logic;  -- 1 = Green Light active
        game_active_i   : in  std_logic;  -- 1 between first button press and game end
        switch_i        : in  std_logic;  -- player's slide switch
        set_winner_i    : in  std_logic;  -- latches winner flag (from top)
        distance_o      : out unsigned(3 downto 0);
        eliminated_o    : out std_logic;
        winner_o        : out std_logic;
        reached_finish_o: out std_logic
    );
end entity;

architecture rtl of player_unit is
    constant FINISH : unsigned(3 downto 0) := to_unsigned(12, 4);
    signal distance_r   : unsigned(3 downto 0) := (others => '0');
    signal eliminated_r : std_logic := '0';
    signal winner_r     : std_logic := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                distance_r   <= (others => '0');
                eliminated_r <= '0';
                winner_r     <= '0';
            else
                -- Latch winner flag when commanded by top-level arbiter
                if set_winner_i = '1' then
                    winner_r <= '1';
                end if;

                -- Movement / elimination logic only on 1 Hz tick
                if tick_i = '1' and eliminated_r = '0' and game_active_i = '1' then
                    if switch_i = '1' then
                        if is_green_i = '1' then
                            -- Advance by 1 meter, saturate at finish
                            if distance_r < FINISH then
                                distance_r <= distance_r + 1;
                            end if;
                        else
                            -- Moved during Red Light -> eliminated
                            eliminated_r <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    distance_o       <= distance_r;
    eliminated_o     <= eliminated_r;
    winner_o         <= winner_r;
    reached_finish_o <= '1' when (distance_r = FINISH and eliminated_r = '0') else '0';
end architecture;
