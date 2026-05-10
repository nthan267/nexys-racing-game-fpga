


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity game_fsm is
    generic (
        BONUS_EN : std_logic := '1'
    );
    port (
        clk              : in  std_logic;
        rst              : in  std_logic;
        tick_i           : in  std_logic;   -- 1 Hz
        btn_pulse_i      : in  std_logic;   -- 1-cycle pulse on button press
        rand_i           : in  std_logic_vector(7 downto 0);
        any_finished_i   : in  std_logic;   -- any player at 12 m?
        all_eliminated_i : in  std_logic;

        is_green_o       : out std_logic;
        game_active_o    : out std_logic;
        game_done_o      : out std_logic;
        iter_num_o       : out unsigned(3 downto 0);  -- 1..10, 0 when idle
        time_left_o      : out unsigned(3 downto 0);  -- current seconds remaining
        latch_winner_o   : out std_logic              -- 1-cycle pulse: arbiter should latch
    );
end entity;

architecture rtl of game_fsm is
    type state_t is (S_IDLE, S_GREEN, S_RED, S_DONE);
    signal state, state_n : state_t := S_IDLE;

    signal iter       : unsigned(3 downto 0) := (others => '0');
    signal time_left  : unsigned(3 downto 0) := (others => '0');
    signal latch_win  : std_logic := '0';

    -- Nominal duration lookup: iter 1..10 -> seconds
    function nominal_duration(i : unsigned) return unsigned is
    begin
        case to_integer(i) is
            when 1 => return to_unsigned(6, 4);
            when 2 => return to_unsigned(4, 4);
            when 3 => return to_unsigned(3, 4);
            when 4 => return to_unsigned(2, 4);
            when others => return to_unsigned(1, 4);  -- iter 5..10
        end case;
    end function;

  
    function apply_random(nom : unsigned; r : std_logic_vector(1 downto 0))
        return unsigned is
        variable result : integer;
    begin
        result := to_integer(nom);
        case r is
            when "00"   => result := result - 1;
            when "11"   => result := result + 1;
            when others => null;
        end case;
        if result < 1 then
            result := 1;
        end if;
        return to_unsigned(result, 4);
    end function;

begin
    -- State register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state      <= S_IDLE;
                iter       <= (others => '0');
                time_left  <= (others => '0');
                latch_win  <= '0';
            else
                latch_win <= '0';  -- default: deassert each cycle

                case state is
                    when S_IDLE =>
                        if btn_pulse_i = '1' then
                            iter      <= to_unsigned(1, 4);
                            if BONUS_EN = '1' then
                                time_left <= apply_random(nominal_duration(to_unsigned(1,4)),
                                                          rand_i(1 downto 0));
                            else
                                time_left <= nominal_duration(to_unsigned(1,4));
                            end if;
                            state <= S_GREEN;
                        end if;

                    when S_GREEN =>
                        -- Check for winner first (priority over timer)
                        if any_finished_i = '1' then
                            latch_win <= '1';
                            state     <= S_DONE;
                        elsif all_eliminated_i = '1' then
                            state <= S_DONE;
                        elsif tick_i = '1' then
                            if time_left = 1 then
                                time_left <= (others => '0');
                                -- Green Light period just ended
                                if iter = 10 then
                                    state <= S_DONE;
                                else
                                    state <= S_RED;
                                end if;
                            else
                                time_left <= time_left - 1;
                            end if;
                        end if;

                    when S_RED =>
                        if all_eliminated_i = '1' then
                            state <= S_DONE;
                        elsif any_finished_i = '1' then
                            -- Shouldn't happen (can't advance in Red), but guard anyway
                            latch_win <= '1';
                            state     <= S_DONE;
                        elsif btn_pulse_i = '1' then
                            iter <= iter + 1;
                            if BONUS_EN = '1' then
                                time_left <= apply_random(nominal_duration(iter + 1),
                                                          rand_i(1 downto 0));
                            else
                                time_left <= nominal_duration(iter + 1);
                            end if;
                            state <= S_GREEN;
                        end if;

                    when S_DONE =>
                        -- Stay here until reset
                        null;
                end case;
            end if;
        end if;
    end process;

    -- Outputs
    is_green_o     <= '1' when state = S_GREEN else '0';
    game_active_o  <= '1' when (state = S_GREEN or state = S_RED) else '0';
    game_done_o    <= '1' when state = S_DONE else '0';
    iter_num_o     <= iter;
    time_left_o    <= time_left;
    latch_winner_o <= latch_win;
end architecture;
