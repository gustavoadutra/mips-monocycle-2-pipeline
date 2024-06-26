library IEEE;
use IEEE.std_logic_1164.all;

entity ForwardingUnit is
    port (
        -- Inputs
        clock               : in  std_logic;
        reset               : in  std_logic;
        writeRegister_4     : in  std_logic_vector(4 downto 0);
        writeRegister_3     : in  std_logic_vector(4 downto 0);
        rs_2                : in  std_logic_vector(4 downto 0);
        rt_2                : in  std_logic_vector(4 downto 0);
        RegWrite_3          : in  std_logic;
        RegWrite_4          : in  std_logic;
        -- Outputs
        forward_a           : out std_logic_vector(1 downto 0);
        forward_b           : out std_logic_vector(1 downto 0)
    );
end entity ForwardingUnit;

architecture Behavioral of ForwardingUnit is
begin 
    process(clock, reset)
    begin
        if reset = '1' then
            forward_a <= "00";
            forward_b <= "00";
        elsif rising_edge(clock) then
            if RegWrite_3 = '1' and writeRegister_3 /= "00000" and writeRegister_3 = rs_2 then
                forward_a <= "10";
            elsif RegWrite_4 = '1' and writeRegister_4 /= "00000" and writeRegister_4 = rs_2 then
                forward_a <= "01";
            else
                forward_a <= "00";
            end if;
            
            if RegWrite_3 = '1' and writeRegister_3 /= "00000" and writeRegister_3 = rt_2 then
                forward_b <= "10";
            elsif RegWrite_4 = '1' and writeRegister_4 /= "00000" and writeRegister_4 = rt_2 then
                forward_b <= "01";
            else
                forward_b <= "00";
            end if;
        end if;
    end process;
end architecture Behavioral;