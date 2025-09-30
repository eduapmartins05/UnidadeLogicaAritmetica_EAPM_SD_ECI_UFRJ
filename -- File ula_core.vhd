-- File: ula_core.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ula_core is
    port (
        OPCODE : in  std_logic_vector(3 downto 0);
        A      : in  std_logic_vector(3 downto 0);
        B      : in  std_logic_vector(3 downto 0);
        RESULT : out std_logic_vector(3 downto 0);
        Z_FLAG : out std_logic; -- Zero Flag
        N_FLAG : out std_logic; -- Negative Flag
        C_FLAG : out std_logic; -- Carry Out Flag
        V_FLAG : out std_logic  -- Overflow Flag
    );
end ula_core;

architecture Behavioral of ula_core is
begin
    process(OPCODE, A, B)
        -- Use 5-bit variables to handle carry out for arithmetic operations.
        variable res_ext : std_logic_vector(4 downto 0);
        variable result_temp : std_logic_vector(3 downto 0);
    begin
        res_ext := (others => '0');
        V_FLAG  <= '0';
        C_FLAG  <= '0';
       
        -- Select the operation based on the OPCODE
        case OPCODE is
            -- 0000: A + B (Addition)
            when "0000" =>
                res_ext := std_logic_vector(resize(signed('0' & A), 5) + resize(signed('0' & B), 5));
                if (A(3) = B(3)) and (A(3) /= res_ext(3)) then V_FLAG <= '1'; end if;
            -- 0001: A - B (Subtraction)
            when "0001" =>
                res_ext := std_logic_vector(resize(signed('0' & A), 5) - resize(signed('0' & B), 5));
                if (A(3) /= B(3)) and (B(3) = res_ext(3)) then V_FLAG <= '1'; end if;
            -- 0010: A AND B
            when "0010" => res_ext(3 downto 0) := A and B;
            -- 0011: A OR B
            when "0011" => res_ext(3 downto 0) := A or B;
            -- 0100: A XOR B
            when "0100" => res_ext(3 downto 0) := A xor B;
            -- 0101: NOT A
            when "0101" => res_ext(3 downto 0) := not A;
            -- 0110: A + 1 (Increment)
            when "0110" =>
                res_ext := std_logic_vector(resize(signed('0' & A), 5) + 1);
                if (A = "0111") then V_FLAG <= '1'; end if;
            -- 0111: A - 1 (Decrement)
            when "0111" =>
                res_ext := std_logic_vector(resize(signed('0' & A), 5) - 1);
                if (A = "1000") then V_FLAG <= '1'; end if;
            -- Default case for any other opcode
            when others => res_ext := (others => '0');
        end case;
       
        result_temp := res_ext(3 downto 0);
       
        -- Assign final outputs
        RESULT <= result_temp;
        C_FLAG <= res_ext(4); -- The carry out is the 5th bit
       
        -- Calculate Zero and Negative flags based on the 4-bit result
        if result_temp = "0000" then Z_FLAG <= '1'; else Z_FLAG <= '0'; end if;
        N_FLAG <= result_temp(3); -- The Negative flag is the MSB of the result
    end process;
end Behavioral;