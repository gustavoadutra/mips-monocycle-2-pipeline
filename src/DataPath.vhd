-------------------------------------------------------------------------
-- Design unit: Data path
-- Description: MIPS data path supporting ADDU, SUBU, AND, OR, LW, SW,  
--                  ADDIU, ORI, SLT, BEQ, J, LUI instructions.
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all; 
use work.MIPS_package.all;

   
entity DataPath is
    generic (
        PC_START_ADDRESS    : integer := 0
    );
    port (  
        clock               : in  std_logic;
        reset               : in  std_logic;
        instructionAddress  : out std_logic_vector(31 downto 0);  -- Instruction memory address bus
        instruction         : in  std_logic_vector(31 downto 0);  -- Data bus from instruction memory
        dataAddress         : out std_logic_vector(31 downto 0);  -- Data memory address bus
        data_i              : in  std_logic_vector(31 downto 0);  -- Data bus from data memory 
        data_o              : out std_logic_vector(31 downto 0);  -- Data bus to data memory
        uins                : in  Microinstruction                -- Control path microinstruction
    );
end DataPath;


architecture structural of DataPath is

    signal incrementedPC, pc_q, result, readData1, readData2, ALUoperand2, signExtended, zeroExtended, writeData: std_logic_vector(31 downto 0);
    signal branchOffset, branchTarget, pc_d: std_logic_vector(31 downto 0);
    signal jumpTarget: std_logic_vector(31 downto 0);
    signal writeRegister   : std_logic_vector(4 downto 0);

    -- Pipeline registers
    -- Stage 1 IF/ID
    signal uins_1         : Microinstruction;
    signal instruction_1: std_logic_vector(31 downto 0);
    signal incrementedPC_1: std_logic_vector(31 downto 0);

    -- Stage 2 EX/MEM
    signal uins_2: Microinstruction;
    signal instruction_2: std_logic_vector(31 downto 0);
    signal incrementedPC_2: std_logic_vector(31 downto 0);

    signal writeRegister_2: std_logic_vector(4 downto 0);
    signal readData1_2, readData2_2: std_logic_vector(31 downto 0);
    signal signExtended_2: std_logic_vector(31 downto 0);

    -- Stage 3 MEM/WB
    signal uins_3: Microinstruction;
    signal instruction_3: std_logic_vector(31 downto 0);
    signal incrementedPC_3: std_logic_vector(31 downto 0);

    signal writeRegister_3: std_logic_vector(4 downto 0);
    signal result_3: std_logic_vector(31 downto 0);

    -- Stage 4 WB
    signal uins_4: Microinstruction;
    signal instruction_4: std_logic_vector(31 downto 0);
    
    signal writeRegister_4: std_logic_vector(4 downto 0);
    signal result_4: std_logic_vector(31 downto 0);
    signal data_i_4: std_logic_vector(31 downto 0);

    -- Retrieves the rs field from the instruction
    alias rs: std_logic_vector(4 downto 0) is instruction_1(25 downto 21);
        
    -- Retrieves the rt field from the instruction
    alias rt: std_logic_vector(4 downto 0) is instruction_1(20 downto 16);
        
    -- Retrieves the rd field from the instruction
    alias rd: std_logic_vector(4 downto 0) is instruction_1(15 downto 11);
    
    signal zero : std_logic; 
    
begin

    -- incrementedPC points the next instruction address
    -- ADDER over the PC register
    ADDER_PC: incrementedPC <= STD_LOGIC_VECTOR(UNSIGNED(pc_q) + TO_UNSIGNED(4,32));
    
    -- PC register
    PROGRAM_COUNTER:    entity work.RegisterNbits
        generic map (
            LENGTH      => 32,
            INIT_VALUE  => PC_START_ADDRESS
        )
        port map (
            clock       => clock,
            reset       => reset,
            ce          => '1', 
            d           => pc_d, 
            q           => pc_q
        );
        
    -- Instruction memory is addressed by the PC register
    instructionAddress <= pc_q;

    -- Selects the instruction field witch contains the register to be written
    -- MUX at the register file input
    MUX_RF: writeRegister <= rt when uins_1.regDst = '0' else rd;
    
    -- Sign extends the low 16 bits of instruction 
    SIGN_EX: signExtended <= x"FFFF" & instruction_1(15 downto 0) when instruction_1(15) = '1' else 
                    x"0000" & instruction_1(15 downto 0);
                    
    -- Zero extends the low 16 bits of instruction 
    ZERO_EX: zeroExtended <= x"0000" & instruction_2(15 downto 0);
       
    -- Converts the branch offset from words to bytes (multiply by 4) 
    -- Hardware at the second ADDER input
    -- SHIFT_L: branchOffset <= signExtended(29 downto 0) & "00";
    
    -- Branch target address
    -- Branch ADDER
    -- ADDER_BRANCH: branchTarget <= STD_LOGIC_VECTOR(UNSIGNED(incrementedPC) + UNSIGNED(branchOffset));
    
    -- Jump target address
    jumpTarget <= incrementedPC_3(31 downto 28) & instruction_3(25 downto 0) & "00";
    
    -- MUX which selects the PC value
    MUX_PC: pc_d <= jumpTarget when uins_3.Jump = '1' else
                    incrementedPC;
      
    -- Selects the second ALU operand
    -- MUX at the ALU input
    MUX_ALU: ALUoperand2 <= readData2_2 when uins_2.ALUSrc = "00" else
                            zeroExtended when uins_2.ALUSrc = "01" else
                            signExtended_2;
    
    -- Selects the data to be written in the register file
    -- MUX at the data memory output
    -- Write data comes from stage 4 of the pipeline
    MUX_DATA_MEM: writeData <= data_i_4 when uins_4.memToReg = '1' else result_4;
    
    -- Data to data memory comes from the second read register at register file
    data_o <= readData2_2;
    
    -- ALU output address the data memory
    dataAddress <= result_3;

    -- Pipeline stage 1 IF/ID
    stage_1: process(clock, reset)
    begin
        if reset = '1' then
            instruction_1 <= (others => '0');
            incrementedPC_1 <= (others => '0');

        elsif rising_edge(clock) then
            uins_1 <= uins;
            instruction_1 <= instruction;
            incrementedPC_1 <= incrementedPC;

        end if;
    end process stage_1;

    -- Pipeline stage 2 EX/MEM
    stage_2: process(clock, reset)
    begin
        if reset = '1' then
            instruction_2 <= (others => '0');
            incrementedPC_2 <= (others => '0');
            
            readData1_2 <= (others => '0');
            readData2_2 <= (others => '0');
            signExtended_2 <= (others => '0');
            jumpTarget_2 <= (others => '0');
            writeRegister_2 <= (others => '0');

        elsif rising_edge(clock) then
            uins_2 <= uins_1;
            instruction_2 <= instruction_1;
            incrementedPC_2 <= incrementedPC_1;

            writeRegister_2 <= writeRegister;
            readData1_2 <= readData1;
            readData2_2 <= readData2;
            signExtended_2 <= signExtended;
        end if;
    end process stage_2;

    -- Pipeline stage 3 MEM/WB
    stage_3: process(clock, reset)
    begin
        if reset = '1' then
            instruction_3 <= (others => '0');
            incrementedPC_3 <= (others => '0');

            writeRegister_3 <= (others => '0');
            jumpTarget_3 <= (others => '0');
            result_3 <= (others => '0');

        elsif rising_edge(clock) then
            uins_3 <= uins_2;
            instruction_3 <= instruction_2;
            incrementedPC_3 <= incrementedPC_2;

            writeRegister_3 <= writeRegister_2;
            result_3 <= result;
        end if;
    end process stage_3;

    -- Pipeline stage 4
    stage_4: process(clock, reset)
    begin
        if reset = '1' then
            instruction_4 <= (others => '0');
    
            writeRegister_4 <= (others => '0');
            result_4 <= (others => '0');
            data_i_4 <= (others => '0');

        elsif rising_edge(clock) then
            uins_4 <= uins_3;
            instruction_4 <= instruction_3;

            writeRegister_4 <= writeRegister_3;
            result_4 <= result_3;
            data_i_4 <= data_i;
        end if;
    end process stage_4;

    -- Register file
    REGISTER_FILE: entity work.RegisterFile(structural)
        port map (
            clock            => clock,
            reset            => reset,            
            write            => uins_4.RegWrite,            
            readRegister1    => rs,    
            readRegister2    => rt,
            writeRegister    => writeRegister_4,
            writeData        => writeData,          
            readData1        => readData1,        
            readData2        => readData2
        );
    
    
    -- Arithmetic/Logic Unit
    ALU: entity work.ALU(behavioral)
        port map (
            operand1    => readData1_2,
            operand2    => ALUoperand2,
            result      => result,
            zero        => zero,
            operation   => uins_2.instruction
        );

end structural;