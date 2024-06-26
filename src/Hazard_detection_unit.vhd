library IEEE;
use IEEE.std_logic_1164.all;

entity HazardDetectionUnit is
    port (
        clock                    : in std_logic;
        reset                    : in std_logic;
        memToReg_2               : in std_logic;
        rt_2                     : in std_logic_vector(4 downto 0);
        rt                       : in std_logic_vector(4 downto 0);
        rs                       : in std_logic_vector(4 downto 0);
        -- Assyncronous signal output
        data_dependency          : out std_logic;
        -- Synchronous signal output
        Hazard                   : out std_logic
    );
end HazardDetectionUnit;

architecture Behavioral of HazardDetectionUnit is
begin
    -- Data dependency detection assyncronous 
    data_dependency <= '0' when (rt_2 = rs or rt_2 = rt) and memToReg_2 = '1' else
                        '1';

    process(clock, reset)
    begin
        if reset = '1' then
            Hazard <= '0';
        elsif rising_edge(clock) then
            if ((rt_2 = rs or rt_2 = rt) and memToReg_2 = '1') then
                Hazard <= '1';
            else
                Hazard <= '0';
            end if;
        end if;
    end process;
end Behavioral;