-- File: ula_top.vhd
library ieee;
use ieee.std_logic_1164.all;

entity ula_top is
    generic (
        -- Genéricos para configurar os debouncers
        CLK_FREQ    : integer := 50000;
        DEBOUNCE_MS : integer := 20;
        LOCKOUT_MS  : integer := 400;
        STR_RESET_CICLES : integer := 255
    );
    port (
        CLK         : in  std_logic;
        BTN_RESET   : in  std_logic;
        BTN_SHOW    : in  std_logic;
        BTN_POKEMON : in  std_logic;
        BTN_RESULT  : in  std_logic;
        SWITCHES    : in  std_logic_vector(3 downto 0);
        LED_RESULT  : out std_logic_vector(3 downto 0);
        LED_ZERO    : out std_logic;
        LED_NEGATIVE: out std_logic;
        LED_CARRY   : out std_logic;
        LED_OVERFLOW: out std_logic
    );
end ula_top;

architecture Behavioral of ula_top is

    component ula_core is
        port ( 
            OPCODE : in  std_logic_vector(3 downto 0); 
            A      : in  std_logic_vector(3 downto 0); 
            B      : in  std_logic_vector(3 downto 0); 
            RESULT : out std_logic_vector(3 downto 0); 
            Z_FLAG : out std_logic; 
            N_FLAG : out std_logic; 
            C_FLAG : out std_logic; 
            V_FLAG : out std_logic 
        );
    end component;

    component debouncer is
        generic (
            CLK_FREQ    : integer := 50000;
            DEBOUNCE_MS : integer := 2;
            LOCKOUT_MS  : integer := 8
        );
        port (
            CLK     : in  std_logic;
            BTN_IN  : in  std_logic;
            BTN_OUT : out std_logic
        );
    end component;

    type state_type is (OP, A, B, BLANK);
    
    signal state_show           : state_type;
    signal state_capture        : state_type;
    signal pokemon_pulse        : std_logic;
    signal pokemon_prev         : std_logic;
    signal show_pulse           : std_logic;
    signal show_prev            : std_logic;
    signal result_pulse         : std_logic;
    signal result_prev          : std_logic;
    signal reset_pulse          : std_logic;
    signal reset_prev           : std_logic;
    signal opcode_reg       : std_logic_vector(3 downto 0);
    signal operand_a_reg    : std_logic_vector(3 downto 0);
    signal operand_b_reg    : std_logic_vector(3 downto 0);
    signal ula_result       : std_logic_vector(3 downto 0);
    signal ula_z_flag       : std_logic;
    signal ula_n_flag       : std_logic;
    signal ula_c_flag       : std_logic;
    signal ula_v_flag       : std_logic;
    signal show_alu_flags   : std_logic;
    signal led_result_reg   : std_logic_vector(3 downto 0);
    
    -- Sinais para reset inicial (Power-On Reset)
    signal reset_counter    : integer range 0 to 255 := 0;
    signal power_on_reset   : std_logic := '1';

begin

    debounce_pokemon : debouncer
        generic map (
            CLK_FREQ    => CLK_FREQ,
            DEBOUNCE_MS => DEBOUNCE_MS,
            LOCKOUT_MS  => LOCKOUT_MS
        )
        port map (
            CLK     => CLK,
            BTN_IN  => BTN_POKEMON,
            BTN_OUT => pokemon_pulse
        );
        
    debounce_reset : debouncer
        generic map (
            CLK_FREQ    => CLK_FREQ,
            DEBOUNCE_MS => DEBOUNCE_MS,
            LOCKOUT_MS  => LOCKOUT_MS
        )
        port map (
            CLK     => CLK,
            BTN_IN  => BTN_RESET,
            BTN_OUT => reset_pulse
        );
        
    debounce_show : debouncer
        generic map (
            CLK_FREQ    => CLK_FREQ,
            DEBOUNCE_MS => DEBOUNCE_MS,
            LOCKOUT_MS  => LOCKOUT_MS
        )
        port map (
            CLK     => CLK,
            BTN_IN  => BTN_SHOW,
            BTN_OUT => show_pulse
        );
        
    debounce_result : debouncer
        generic map (
            CLK_FREQ    => CLK_FREQ,
            DEBOUNCE_MS => DEBOUNCE_MS,
            LOCKOUT_MS  => LOCKOUT_MS
        )
        port map (
            CLK     => CLK,
            BTN_IN  => BTN_RESULT,
            BTN_OUT => result_pulse
        );

    ula_core_inst : ula_core
        port map (
            OPCODE => opcode_reg,
            A      => operand_a_reg,
            B      => operand_b_reg,
            RESULT => ula_result,
            Z_FLAG => ula_z_flag,
            N_FLAG => ula_n_flag,
            C_FLAG => ula_c_flag,
            V_FLAG => ula_v_flag
        );

    -- Processo para gerar o Power-On Reset
    power_on_reset_process: process(CLK)
    begin
        if rising_edge(CLK) then
            if reset_counter < STR_RESET_CICLES then
                reset_counter <= reset_counter + 1;
                power_on_reset <= '1';
            else
                power_on_reset <= '0';
            end if;
        end if;
    end process;

    -- Processo principal com reset inicial
    main_process: process(CLK)
    begin
        if rising_edge(CLK) then
            -- Reset inicial (Power-On Reset) ou reset por botão
            if power_on_reset = '1' or (reset_pulse = '1' and reset_prev = '0') then
                state_show <= OP;
                state_capture <= OP;
                opcode_reg <= (others => '0');
                operand_a_reg <= (others => '0');
                operand_b_reg <= (others => '0');
                led_result_reg <= (others => '0');
                show_alu_flags <= '1';
                pokemon_prev <= '0';
                show_prev <= '0';
                result_prev <= '0';
                reset_prev <= '0';
                
            else
                pokemon_prev <= pokemon_pulse;
                show_prev <= show_pulse;
                result_prev <= result_pulse;
                reset_prev <= reset_pulse;
                
                if pokemon_pulse = '1' and pokemon_prev = '0' then
                    case state_capture is
                        when OP =>
                            opcode_reg <= SWITCHES;
                            led_result_reg <= SWITCHES;
                            state_capture <= A;
                        when A =>
                            operand_a_reg <= SWITCHES;
                            led_result_reg <= SWITCHES;
                            state_capture <= B;
                        when B =>
                            operand_b_reg <= SWITCHES;
                            led_result_reg <= SWITCHES;
                            state_capture <= BLANK;
                        when BLANK =>
                        	led_result_reg <= ula_result;
                            state_capture <= OP;
                    end case;
                    show_alu_flags <= '1';
                    
                elsif show_pulse = '1' and show_prev = '0' then
                    case state_show is
                        when OP =>
                            led_result_reg <= opcode_reg;
                            state_show <= A;
                            show_alu_flags <= '1';
                        when A =>
                            led_result_reg <= operand_a_reg;
                            state_show <= B;
                            show_alu_flags <= '1';
                        when B =>
                            led_result_reg <= operand_b_reg;
                            state_show <= BLANK;
                            show_alu_flags <= '1';
                        when BLANK =>
                            led_result_reg <= (others => '0');
                            state_show <= OP;
                            show_alu_flags <= '0';
                    end case;
                    
                elsif result_pulse = '1' and result_prev = '0' then
                    led_result_reg <= ula_result;
                    show_alu_flags <= '1';
                    state_show <= OP;
                end if;
            end if;
        end if;
    end process;
   
    LED_RESULT <= led_result_reg;
    LED_ZERO <= ula_z_flag when show_alu_flags = '1' else '0';
    LED_NEGATIVE <= ula_n_flag when show_alu_flags = '1' else '0';
    LED_CARRY <= ula_c_flag when show_alu_flags = '1' else '0';
    LED_OVERFLOW <= ula_v_flag when show_alu_flags = '1' else '0';
   
end Behavioral;