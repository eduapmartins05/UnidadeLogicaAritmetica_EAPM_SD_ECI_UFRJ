-- File: ula_top_tb.vhd
-- Description: Testbench for the 4-bit ALU top-level entity
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ula_top_tb is
end ula_top_tb;

architecture Behavioral of ula_top_tb is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz clock
    
    constant CLK_FREQ    : integer := 5000;   -- 50 MHz
    constant DEBOUNCE_MS : integer := 20;
    constant LOCKOUT_MS  : integer := 400;
    constant STR_RESET_CICLES : integer := 255;
    
    signal clk          : std_logic := '0';
    signal btn_reset    : std_logic := '0';
    signal btn_show     : std_logic := '0';
    signal btn_pokemon  : std_logic := '0';
    signal btn_result   : std_logic := '0';
    signal switches     : std_logic_vector(3 downto 0) := (others => '0');
    signal led_result   : std_logic_vector(3 downto 0);
    signal led_zero     : std_logic;
    signal led_negative : std_logic;
    signal led_carry    : std_logic;
    signal led_overflow : std_logic;
    
    shared variable simulation_active : boolean := true;
    
begin

    -- Instantiate the Unit Under Test (UUT)
    uut: entity work.ula_top
        generic map (
            CLK_FREQ    => CLK_FREQ,
            DEBOUNCE_MS => DEBOUNCE_MS,
            LOCKOUT_MS  => LOCKOUT_MS,
            STR_RESET_CICLES => STR_RESET_CICLES
        )
        port map (
            CLK          => clk,
            BTN_RESET    => btn_reset,
            BTN_SHOW     => btn_show,
            BTN_POKEMON  => btn_pokemon,
            BTN_RESULT   => btn_result,
            SWITCHES     => switches,
            LED_RESULT   => led_result,
            LED_ZERO     => led_zero,
            LED_NEGATIVE => led_negative,
            LED_CARRY    => led_carry,
            LED_OVERFLOW => led_overflow
        );

    -- Clock generation process
    clock_process: process
    begin
        while simulation_active loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    stimulus: process
        -- Procedure to simulate button press with debounce timing
        procedure press_button(
            signal btn : out std_logic;
            duration : in integer) is
        begin
            btn <= '1';
            for i in 1 to duration+(CLK_FREQ/1000)*DEBOUNCE_MS loop
                wait until rising_edge(clk);
            end loop;
            btn <= '0';
            wait for (CLK_FREQ/1000)*(DEBOUNCE_MS + LOCKOUT_MS) * CLK_PERIOD;
        end procedure;
        
        -- Procedure to set switches and press pokemon button
        procedure set_value(
            value : in std_logic_vector(3 downto 0);
            press_duration : in integer := 10) is
        begin
            switches <= value;
            wait until rising_edge(clk);
            press_button(btn_pokemon, press_duration);
            wait until rising_edge(clk);
        end procedure;

        -- Procedure to test a specific operation
        procedure test_operation(
            opcode : in std_logic_vector(3 downto 0);
            a_val  : in std_logic_vector(3 downto 0);
            b_val  : in std_logic_vector(3 downto 0);
            expected_result : in std_logic_vector(3 downto 0);
            expected_z : in std_logic;
            expected_n : in std_logic;
            expected_c : in std_logic;
            expected_v : in std_logic;
            test_name : in string) is
        begin
            report "Testing: " & test_name;
            
            -- Reset para começar limpo
            press_button(btn_reset, 15);
            wait for (LOCKOUT_MS+100) * CLK_PERIOD;
            
            -- Configurar operação
            set_value(opcode);   -- OPCODE
            set_value(a_val);    -- Operando A
            set_value(b_val);    -- Operando B
            set_value(opcode);
            
            -- Pressionar result para ver cálculo
            press_button(btn_result, 15);
            wait for (LOCKOUT_MS+100) * CLK_PERIOD;
            
            -- Verificar resultado
            assert led_result = expected_result 
                report test_name & " failed: Expected ";
            
            -- Verificar flags
            assert led_zero = expected_z 
                report test_name & " Z flag error: Expected " & 
                       std_logic'image(expected_z) & " but got " & std_logic'image(led_zero)
                severity error;
            assert led_negative = expected_n 
                report test_name & " N flag error: Expected " & 
                       std_logic'image(expected_n) & " but got " & std_logic'image(led_negative)
                severity error;
            assert led_carry = expected_c 
                report test_name & " C flag error: Expected " & 
                       std_logic'image(expected_c) & " but got " & std_logic'image(led_carry)
                severity error;
            assert led_overflow = expected_v 
                report test_name & " V flag error: Expected " & 
                       std_logic'image(expected_v) & " but got " & std_logic'image(led_overflow)
                severity error;
            
            report test_name & " PASSED";
            wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        end procedure;

    begin
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        
        
        -- Teste 1: ADDITION (5 + 3 = 8)
        test_operation(
            opcode => "0000",  -- ADD
            a_val => "0101",   -- 5
            b_val => "0011",   -- 3
            expected_result => "1000", -- 8
            expected_z => '0', expected_n => '1', expected_c => '0', expected_v => '1',
            test_name => "ADD: 5 + 3 = 8"
        );
        
        -- Teste 2: ADDITION com carry (15 + 1 = 0 com carry)
        test_operation(
            opcode => "0000",  -- ADD
            a_val => "1111",   -- 15
            b_val => "0001",   -- 1
            expected_result => "0000", -- 0 (overflow)
            expected_z => '1', expected_n => '0', expected_c => '1', expected_v => '0',
            test_name => "ADD: 15 + 1 = 0 (carry)"
        );
        
        -- Teste 3: ADDITION com overflow (7 + 1 = -8 em complemento2)
        test_operation(
            opcode => "0000",  -- ADD
            a_val => "0111",   -- 7
            b_val => "0001",   -- 1
            expected_result => "1000", -- -8
            expected_z => '0', expected_n => '1', expected_c => '0', expected_v => '1',
            test_name => "ADD: 7 + 1 = -8 (overflow)"
        );
        
        -- Teste 4: SUBTRACTION (7 - 2 = 5)
        test_operation(
            opcode => "0001",  -- SUB
            a_val => "0111",   -- 7
            b_val => "0010",   -- 2
            expected_result => "0101", -- 5
            expected_z => '0', expected_n => '0', expected_c => '0', expected_v => '0',
            test_name => "SUB: 7 - 2 = 5"
        );
        
        -- Teste 5: SUBTRACTION com borrow (0 - 1 = 15)
        test_operation(
            opcode => "0001",  -- SUB
            a_val => "0000",   -- 0
            b_val => "0001",   -- 1
            expected_result => "1111", -- 15 (borrow)
            expected_z => '0', expected_n => '1', expected_c => '1', expected_v => '0',
            test_name => "SUB: 0 - 1 = 15 (borrow)"
        );
        
        
        -- Teste 6: AND (12 AND 10 = 8)
        test_operation(
            opcode => "0010",  -- AND
            a_val => "1100",   -- 12
            b_val => "1010",   -- 10
            expected_result => "1000", -- 8
            expected_z => '0', expected_n => '1', expected_c => '0', expected_v => '0',
            test_name => "AND: 12 & 10 = 8"
        );
        
        -- Teste 7: OR (5 OR 3 = 7)
        test_operation(
            opcode => "0011",  -- OR
            a_val => "0101",   -- 5
            b_val => "0011",   -- 3
            expected_result => "0111", -- 7
            expected_z => '0', expected_n => '0', expected_c => '0', expected_v => '0',
            test_name => "OR: 5 | 3 = 7"
        );
        
        -- Teste 8: XOR (5 XOR 3 = 6)
        test_operation(
            opcode => "0100",  -- XOR
            a_val => "0101",   -- 5
            b_val => "0011",   -- 3
            expected_result => "0110", -- 6
            expected_z => '0', expected_n => '0', expected_c => '0', expected_v => '0',
            test_name => "XOR: 5 ^ 3 = 6"
        );
        
        -- Teste 9: NOT A (NOT 5 = 10)
        test_operation(
            opcode => "0101",  -- NOT
            a_val => "0101",   -- 5
            b_val => "0000",   -- B ignorado
            expected_result => "1010", -- 10
            expected_z => '0', expected_n => '1', expected_c => '0', expected_v => '0',
            test_name => "NOT: ~5 = 10"
        );
        
        -- Teste 10: NOT A (NOT 0 = 15)
        test_operation(
            opcode => "0101",  -- NOT
            a_val => "0000",   -- 0
            b_val => "0000",   -- B ignorado
            expected_result => "1111", -- 15
            expected_z => '0', expected_n => '1', expected_c => '0', expected_v => '0',
            test_name => "NOT: ~0 = 15"
        );
        
        -- ===== TESTES DE INCREMENTO/DECREMENTO =====
        
        -- Teste 11: INCREMENT (5 + 1 = 6)
        test_operation(
            opcode => "0110",  -- INC
            a_val => "0101",   -- 5
            b_val => "0000",   -- B ignorado
            expected_result => "0110", -- 6
            expected_z => '0', expected_n => '0', expected_c => '0', expected_v => '0',
            test_name => "INC: 5 + 1 = 6"
        );
        
        -- Teste 12: INCREMENT com overflow (15 + 1 = 0)
        test_operation(
            opcode => "0110",  -- INC
            a_val => "1111",   -- 15
            b_val => "0000",   -- B ignorado
            expected_result => "0000", -- 0
            expected_z => '1', expected_n => '0', expected_c => '1', expected_v => '0',
            test_name => "INC: 15 + 1 = 0 (overflow)"
        );
        
        -- Teste 13: DECREMENT (5 - 1 = 4)
        test_operation(
            opcode => "0111",  -- DEC
            a_val => "0101",   -- 5
            b_val => "0000",   -- B ignorado
            expected_result => "0100", -- 4
            expected_z => '0', expected_n => '0', expected_c => '0', expected_v => '0',
            test_name => "DEC: 5 - 1 = 4"
        );
        
        -- Teste 14: DECREMENT com underflow (0 - 1 = 15)
        test_operation(
            opcode => "0111",  -- DEC
            a_val => "0000",   -- 0
            b_val => "0000",   -- B ignorado
            expected_result => "1111", -- 15
            expected_z => '0', expected_n => '1', expected_c => '1', expected_v => '0',
            test_name => "DEC: 0 - 1 = 15 (underflow)"
        );
        
        -- ===== TESTES DE FLAGS ESPECIAIS =====
        
        -- Teste 15: Zero flag (0 + 0 = 0)
        test_operation(
            opcode => "0000",  -- ADD
            a_val => "0000",   -- 0
            b_val => "0000",   -- 0
            expected_result => "0000", -- 0
            expected_z => '1', expected_n => '0', expected_c => '0', expected_v => '0',
            test_name => "ZERO FLAG: 0 + 0 = 0"
        );
        
        -- Teste 16: Negative flag (8 + 8 = 0 com negativo em complemento2)
        test_operation(
            opcode => "0000",  -- ADD
            a_val => "1000",   -- -8
            b_val => "1000",   -- -8
            expected_result => "0000", -- 0 (com carry)
            expected_z => '1', expected_n => '0', expected_c => '1', expected_v => '1',
            test_name => "FLAGS: -8 + -8 = 0 (carry+overflow)"
        );
        
        
        -- Teste 17: Ciclo completo do botão Pokemon
        report "Test 17: Pokemon button complete cycle";
        press_button(btn_reset, 15);
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        
        -- Ciclo: OP -> A -> B -> RESULT -> OP
        switches <= "0010";  -- OPCODE AND
        press_button(btn_pokemon, 15);
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        assert led_result = "0010" report "Pokemon cycle 1 failed" severity error;
        
        switches <= "1100";  -- A = 12
        press_button(btn_pokemon, 15);
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        assert led_result = "1100" report "Pokemon cycle 2 failed" severity error;
        
        switches <= "1010";  -- B = 10
        press_button(btn_pokemon, 15);
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        assert led_result = "1010" report "Pokemon cycle 3 failed" severity error;
        
        press_button(btn_pokemon, 15);  -- Mostra resultado (AND 12 & 10 = 8)
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        assert led_result = "1000" report "Pokemon cycle 4 failed" severity error;
        
        -- Teste 18: Botão Show
        report "Test 18: Show button functionality";
        press_button(btn_show, 15);  -- Mostra OPCODE
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        assert led_result = "0010" report "Show OPCODE failed" severity error;
        
        press_button(btn_show, 15);  -- Mostra A
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        assert led_result = "1100" report "Show A failed" severity error;
        
        press_button(btn_show, 15);  -- Mostra B
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        assert led_result = "1010" report "Show B failed" severity error;
        
        press_button(btn_show, 15);  -- Mostra blank
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        assert led_result = "0000" report "Show blank failed" severity error;
        
        -- Teste 19: Botão Result
        report "Test 19: Result button functionality";
        press_button(btn_result, 15);
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        assert led_result = "1000" report "Result button failed" severity error;
        
        -- Teste 20: Reset final
        report "Test 20: Final reset test";
        press_button(btn_reset, 15);
        wait for (LOCKOUT_MS+100) * CLK_PERIOD;
        assert led_result = "0000" report "Reset failed" severity error;
        
        report "=== ALL TESTS COMPLETED SUCCESSFULLY! ===";
        simulation_active := false;
        wait;
    end process;
end Behavioral;
