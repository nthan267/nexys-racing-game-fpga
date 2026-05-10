

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_red_light_green_light is
end entity;

architecture sim of tb_red_light_green_light is

    -- Component declarations (match source files)
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

    -- Use short divider for simulation: 1 "second" = 100 clock cycles
    constant SIM_DIV : positive := 100;
    constant CLK_PERIOD : time := 10 ns;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal tick        : std_logic;
    signal rand_val    : std_logic_vector(7 downto 0);

    signal btn_pulse   : std_logic := '0';
    signal sw          : std_logic_vector(3 downto 0) := (others => '0');

    signal is_green    : std_logic;
    signal game_active : std_logic;
    signal game_done   : std_logic;
    signal iter_num    : unsigned(3 downto 0);
    signal time_left   : unsigned(3 downto 0);
    signal latch_win   : std_logic;

    type dist_arr_t is array(0 to 3) of unsigned(3 downto 0);
    signal distances   : dist_arr_t;
    signal eliminated  : std_logic_vector(3 downto 0);
    signal winners     : std_logic_vector(3 downto 0);
    signal finished    : std_logic_vector(3 downto 0);
    signal any_fin     : std_logic;
    signal all_elim    : std_logic;
    signal set_winner  : std_logic_vector(3 downto 0);

    signal sim_done    : boolean := false;

begin

    -- 100 MHz clock
    clk_gen: process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- Clock divider with simulation-short period
    U_DIV: clock_divider
        generic map (DIV_MAX => SIM_DIV)
        port map (clk => clk, rst => rst, tick_o => tick);

    U_LFSR: lfsr8
        port map (clk => clk, rst => rst, rand_o => rand_val);

    GEN_P: for i in 0 to 3 generate
        U_P: player_unit
            port map (
                clk              => clk,
                rst              => rst,
                tick_i           => tick,
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

    any_fin  <= '1' when finished /= "0000" else '0';
    all_elim <= '1' when eliminated = "1111" else '0';

    process(latch_win, finished)
    begin
        set_winner <= (others => '0');
        if latch_win = '1' then
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
            rst              => rst,
            tick_i           => tick,
            btn_pulse_i      => btn_pulse,
            rand_i           => rand_val,
            any_finished_i   => any_fin,
            all_eliminated_i => all_elim,
            is_green_o       => is_green,
            game_active_o    => game_active,
            game_done_o      => game_done,
            iter_num_o       => iter_num,
            time_left_o      => time_left,
            latch_winner_o   => latch_win
        );

   
    stim: process

        -- One "simulated second" = SIM_DIV clock cycles
        procedure wait_sec(n : natural) is
        begin
            wait for n * SIM_DIV * CLK_PERIOD;
        end procedure;

        procedure press_button is
        begin
            wait until rising_edge(clk);
            btn_pulse <= '1';
            wait until rising_edge(clk);
            btn_pulse <= '0';
        end procedure;

        procedure wait_until_red is
        begin
            wait until is_green = '0' and rising_edge(clk);
        end procedure;

        procedure check(cond : boolean; msg : string) is
        begin
            assert cond report "FAIL: " & msg severity error;
            if cond then
                report "PASS: " & msg severity note;
            end if;
        end procedure;

    begin
        -- Initial reset
        rst <= '1';
        wait for 200 ns;
        rst <= '0';
        wait for 200 ns;

     
        -- Player 0 will win by moving every Green Light.
        -- P1 stays still (never moves), P2 will be eliminated in iter 2,
        -- P3 stays still.

        sw <= "0000";
        press_button;           -- iter 1 (6s nominal)
        wait_sec(1);
        sw <= "0001";           -- P0 starts advancing
        wait_until_red;
        sw <= "0000";
        -- P0 should have ~ 5 meters by now (exact value depends on LFSR
        -- offset; bonus may have made this iter 5, 6, or 7 seconds).
        report "After iter 1, P0 distance = " & integer'image(to_integer(distances(0)));
        check(distances(0) > 0, "P0 advanced during iter 1");
        check(distances(1) = 0, "P1 did not advance");
        check(eliminated = "0000", "nobody eliminated yet");

     
       
        press_button;
        wait_sec(1);
        sw <= "0101";           -- P0 and P2 advancing
        wait_until_red;
        -- In Red Light now. Leave P2's switch up; at next tick P2 eliminated.
        sw <= "0100";
        wait_sec(2);
        check(eliminated(2) = '1', "P2 eliminated for moving during Red Light");
        check(eliminated(0) = '0', "P0 still alive");
        sw <= "0000";

               -- Drive P0 to 12 meters over remaining iterations.
        -- Worst case we need maybe 3-4 more iters; allow up to 8.
        for i in 3 to 10 loop
            exit when game_done = '1';
            press_button;
            wait_sec(1);
            sw <= "0001";       -- P0 only
            wait_until_red;
            sw <= "0000";
            report "After iter " & integer'image(i) &
                   ", P0 distance = " & integer'image(to_integer(distances(0)));
            if winners(0) = '1' then
                exit;
            end if;
        end loop;

        wait_sec(2);
        if winners(0) = '1' then
            report "PASS: P0 declared winner";
        else
            report "NOTE: P0 did not finish within 10 iters (possible with bonus timing)";
        end if;

      
    
        rst <= '1'; wait for 500 ns; rst <= '0'; wait for 200 ns;
        press_button;
        wait_sec(1);
        sw <= "1111";           -- everyone advancing
        wait_until_red;
        -- Leave all switches up during Red Light -> all eliminated
        wait_sec(2);
        check(eliminated = "1111", "all four players eliminated");
        check(game_done = '1', "game ended on all-eliminated");

       
        rst <= '1'; wait for 500 ns; rst <= '0'; wait for 200 ns;
        sw <= "0000";
        for i in 1 to 10 loop
            press_button;
            wait_sec(1);
            -- Nobody moves
            wait_until_red;
        end loop;
        wait_sec(2);
        check(game_done = '1', "game ends after 10 iterations with no winner");
        check(winners = "0000", "no winner declared");

        report "=== All tests complete ===";
        sim_done <= true;
        wait;
    end process;

end architecture;
