
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity red_light_green_light is
    generic (
        SIM_MODE : std_logic := '0'  -- '1' shortens counters for simulation
    );
    port (
        clk     : in  std_logic;
        btn_rst : in  std_logic;
        btn_go  : in  std_logic;
        sw      : in  std_logic_vector(3 downto 0);

        led     : out std_logic_vector(3 downto 0);
        an      : out std_logic_vector(7 downto 0);
        seg     : out std_logic_vector(6 downto 0)
    );
end entity;

architecture rtl of red_light_green_light is

  
    
    component debouncer is
        generic (STABLE_CYCLES : positive := 1_000_000);
        port (
            clk : in std_logic; rst : in std_logic;
            noisy_i : in std_logic;
            clean_o : out std_logic; pulse_o : out std_logic
        );
    end component;

    component clock_divider is
        generic (DIV_MAX : positive := 100_000_000);
        port (
            clk : in std_logic; rst : in std_logic;
            tick_o : out std_logic
        );
    end component;

    component lfsr8 is
        port (
            clk : in std_logic; rst : in std_logic;
            rand_o : out std_logic_vector(7 downto 0)
        );
    end component;

    component player_unit is
        port (
            clk : in std_logic; rst : in std_logic;
            tick_i : in std_logic;
            is_green_i : in std_logic;
            game_active_i : in std_logic;
            switch_i : in std_logic;
            set_winner_i : in std_logic;
            distance_o : out unsigned(3 downto 0);
            eliminated_o : out std_logic;
            winner_o : out std_logic;
            reached_finish_o : out std_logic
        );
    end component;

    component game_fsm is
        generic (BONUS_EN : std_logic := '1');
        port (
            clk : in std_logic; rst : in std_logic;
            tick_i : in std_logic;
            btn_pulse_i : in std_logic;
            rand_i : in std_logic_vector(7 downto 0);
            any_finished_i : in std_logic;
            all_eliminated_i : in std_logic;
            is_green_o : out std_logic;
            game_active_o : out std_logic;
            game_done_o : out std_logic;
            iter_num_o : out unsigned(3 downto 0);
            time_left_o : out unsigned(3 downto 0);
            latch_winner_o : out std_logic
        );
    end component;

    component display_mux is
        port (
            clk : in std_logic; rst : in std_logic;
            digits_i : in std_logic_vector(31 downto 0);
            blank_i : in std_logic_vector(7 downto 0);
            dash_i : in std_logic_vector(7 downto 0);
            an_o : out std_logic_vector(7 downto 0);
            seg_o : out std_logic_vector(6 downto 0)
        );
    end component;

    
   
    constant DEB_CYC : positive := 1_000_000;    -- 10 ms real, use smaller in sim TB
    constant DIV_MAX : positive := 100_000_000;  -- 1 s real

    signal rst_sync     : std_logic := '0';
    signal btn_clean    : std_logic;
    signal btn_pulse    : std_logic;
    signal tick_1hz     : std_logic;
    signal rand_val     : std_logic_vector(7 downto 0);

    signal is_green     : std_logic;
    signal game_active  : std_logic;
    signal game_done    : std_logic;
    signal iter_num     : unsigned(3 downto 0);
    signal time_left    : unsigned(3 downto 0);
    signal latch_winner : std_logic;

    type dist_array_t is array (0 to 3) of unsigned(3 downto 0);
    signal distances    : dist_array_t;
    signal eliminated   : std_logic_vector(3 downto 0);
    signal winners      : std_logic_vector(3 downto 0);
    signal finished     : std_logic_vector(3 downto 0);
    signal any_finished : std_logic;
    signal all_elim     : std_logic;

       signal set_winner   : std_logic_vector(3 downto 0);

    -- Blink generator for winner LEDs (~2 Hz)
    signal blink_cnt    : unsigned(25 downto 0) := (others => '0');
    signal blink        : std_logic;

    -- 7-seg BCD conversion for iteration number (1..10 -> 2 decimal digits)
    signal iter_tens    : std_logic_vector(3 downto 0);
    signal iter_ones    : std_logic_vector(3 downto 0);

    -- Display buses
    signal digits_bus   : std_logic_vector(31 downto 0);
    signal blank_bus    : std_logic_vector(7 downto 0);
    signal dash_bus     : std_logic_vector(7 downto 0);

begin


    -- Reset synchronizer 
  
    process(clk)
        variable s1 : std_logic := '0';
    begin
        if rising_edge(clk) then
            s1       := btn_rst;
            rst_sync <= s1;
        end if;
    end process;


    -- Button debouncer
   
    U_DEB: debouncer
        generic map (STABLE_CYCLES => DEB_CYC)
        port map (
            clk     => clk,
            rst     => rst_sync,
            noisy_i => btn_go,
            clean_o => btn_clean,
            pulse_o => btn_pulse
        );


    -- 1 Hz tick
  
    U_DIV: clock_divider
        generic map (DIV_MAX => DIV_MAX)
        port map (
            clk    => clk,
            rst    => rst_sync,
            tick_o => tick_1hz
        );

    
    U_LFSR: lfsr8
        port map (
            clk    => clk,
            rst    => rst_sync,
            rand_o => rand_val
        );

      GEN_PLAYERS: for i in 0 to 3 generate
        U_P: player_unit
            port map (
                clk              => clk,
                rst              => rst_sync,
                tick_i           => tick_1hz,
                is_green_i       => is_green,
                game_active_i    => game_active,
                switch_i         => sw(i),
                set_winner_i     => set_winner(i),
                distance_o       => distances(i),
                eliminated_o     => eliminated(i),
                winner_o         => winners(i),
                reached_finish_o => finished(i)
            );
    end generate;

 
    any_finished <= '1' when (finished /= "0000") else '0';
    all_elim     <= '1' when (eliminated = "1111") else '0';

      process(latch_winner, finished)
    begin
        set_winner <= (others => '0');
        if latch_winner = '1' then
            if    finished(0) = '1' then set_winner(0) <= '1';
            elsif finished(1) = '1' then set_winner(1) <= '1';
            elsif finished(2) = '1' then set_winner(2) <= '1';
            elsif finished(3) = '1' then set_winner(3) <= '1';
            end if;
        end if;
    end process;

  
    U_FSM: game_fsm
        generic map (BONUS_EN => '1')
        port map (
            clk              => clk,
            rst              => rst_sync,
            tick_i           => tick_1hz,
            btn_pulse_i      => btn_pulse,
            rand_i           => rand_val,
            any_finished_i   => any_finished,
            all_eliminated_i => all_elim,
            is_green_o       => is_green,
            game_active_o    => game_active,
            game_done_o      => game_done,
            iter_num_o       => iter_num,
            time_left_o      => time_left,
            latch_winner_o   => latch_winner
        );

  
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_sync = '1' then
                blink_cnt <= (others => '0');
            else
                blink_cnt <= blink_cnt + 1;
            end if;
        end if;
    end process;
    blink <= blink_cnt(25);  -- toggles ~1.5 Hz at 100 MHz

        GEN_LED: for i in 0 to 3 generate
        led(i) <= blink when winners(i) = '1' else
                  '0'   when eliminated(i) = '1' else
                  '1';
    end generate;


    process(iter_num)
    begin
        if iter_num = to_unsigned(10, 4) then
            iter_tens <= x"1";
            iter_ones <= x"0";
        else
            iter_tens <= x"0";
            iter_ones <= std_logic_vector(iter_num);
        end if;
    end process;

      digits_bus(3  downto 0)  <= std_logic_vector(distances(0));  -- digit 0: P1
    digits_bus(7  downto 4)  <= std_logic_vector(distances(1));  -- digit 1: P2
    digits_bus(11 downto 8)  <= std_logic_vector(distances(2));  -- digit 2: P3
    digits_bus(15 downto 12) <= std_logic_vector(distances(3));  -- digit 3: P4
    digits_bus(19 downto 16) <= x"0";                            -- digit 4: blank
    digits_bus(23 downto 20) <= std_logic_vector(time_left);     -- digit 5: time
    digits_bus(27 downto 24) <= iter_ones;                       -- digit 6: iter ones
    digits_bus(31 downto 28) <= iter_tens;                       -- digit 7: iter tens


    blank_bus(0) <= '0';
    blank_bus(1) <= '0';
    blank_bus(2) <= '0';
    blank_bus(3) <= '0';
    blank_bus(4) <= '1';
    blank_bus(5) <= '0';
    blank_bus(6) <= '0';
    blank_bus(7) <= '1' when iter_tens = x"0" else '0';

    
    dash_bus(0) <= eliminated(0);
    dash_bus(1) <= eliminated(1);
    dash_bus(2) <= eliminated(2);
    dash_bus(3) <= eliminated(3);
    dash_bus(4) <= '0';
    dash_bus(5) <= '0';
    dash_bus(6) <= '0';
    dash_bus(7) <= '0';

        U_DISP: display_mux
        port map (
            clk      => clk,
            rst      => rst_sync,
            digits_i => digits_bus,
            blank_i  => blank_bus,
            dash_i   => dash_bus,
            an_o     => an,
            seg_o    => seg
        );

end architecture;
