
# run_sim.do  --  ModelSim simulation 
# COEN 313 Winter 2026 Mini-Project

#     do run_sim.do



vlib work

# Add useful waves
add wave -divider "CLOCK/RESET"
add wave sim:/tb_red_light_green_light/clk
add wave sim:/tb_red_light_green_light/rst
add wave sim:/tb_red_light_green_light/tick

add wave -divider "FSM"
add wave sim:/tb_red_light_green_light/btn_pulse
add wave sim:/tb_red_light_green_light/is_green
add wave sim:/tb_red_light_green_light/game_active
add wave sim:/tb_red_light_green_light/game_done
add wave -radix unsigned sim:/tb_red_light_green_light/iter_num
add wave -radix unsigned sim:/tb_red_light_green_light/time_left
add wave sim:/tb_red_light_green_light/latch_win

add wave -divider "PLAYERS"
add wave sim:/tb_red_light_green_light/sw
add wave -radix unsigned sim:/tb_red_light_green_light/distances
add wave sim:/tb_red_light_green_light/eliminated
add wave sim:/tb_red_light_green_light/winners
add wave sim:/tb_red_light_green_light/finished

add wave -divider "RNG"
add wave -radix hexadecimal sim:/tb_red_light_green_light/rand_val

# Run
run 500 us
wave zoom full
