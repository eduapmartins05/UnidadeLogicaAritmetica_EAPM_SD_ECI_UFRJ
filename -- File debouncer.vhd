-- File: debouncer.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debouncer is
    generic (
        CLK_FREQ    : integer := 50_000_000;  -- 50 MHz
        DEBOUNCE_MS : integer := 10;          -- 10 ms para debounce
        LOCKOUT_MS  : integer := 400          -- 400 ms de lockout
    );
    port (
        CLK     : in  std_logic;
        BTN_IN  : in  std_logic;
        BTN_OUT : out std_logic
    );
end debouncer;

architecture Behavioral of debouncer is
    constant DEBOUNCE_MAX : integer := (CLK_FREQ / 1000) * DEBOUNCE_MS;
    constant LOCKOUT_MAX  : integer := (CLK_FREQ / 1000) * LOCKOUT_MS;
    
    type state_type is (IDLE, DEBOUNCING, LOCKOUT);
    signal state : state_type := IDLE;
    
    signal counter : integer range 0 to LOCKOUT_MAX := 0;
    signal q1, q2  : std_logic := '0';
    signal output_pulse : std_logic := '0';
    
begin
    process(CLK)
    begin
        if rising_edge(CLK) then
            -- Sincronização contra metaestabilidade
            q1 <= BTN_IN;
            q2 <= q1;
            
            case state is
                when IDLE =>
                    output_pulse <= '0';
                    if q2 = '1' then  -- Botão pressionado
                        state <= DEBOUNCING;
                        counter <= 0;
                    end if;
                    
                when DEBOUNCING =>
                    if counter < DEBOUNCE_MAX then
                        counter <= counter + 1;
                    else
                        -- Verifica se ainda está pressionado após debounce
                        if q2 = '1' then
                            output_pulse <= '1';
                            state <= LOCKOUT;
                            counter <= 0;
                        else
                            state <= IDLE;  -- Falso positivo (ruído)
                        end if;
                    end if;
                    
                when LOCKOUT =>
                    output_pulse <= '0';
                    if counter < LOCKOUT_MAX then
                        counter <= counter + 1;
                    else
                        state <= IDLE;  -- Fim do período de lockout
                    end if;
                    
            end case;
        end if;
    end process;
    
    BTN_OUT <= output_pulse;

end Behavioral;

