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
        uins                : in  Microinstruction;                -- Control path microinstruction
        uins_out            : out Microinstruction                -- Data path microinstruction
    );
end DataPath;


architecture structural of DataPath is

    signal incrementedPC, pc_q, result, readData1, readData2,ALUoperand1, ALUoperand2, ALUoperand2_mono, signExtended, zeroExtended, writeData: std_logic_vector(31 downto 0);
    signal branchOffset, branchTarget, pc_d: std_logic_vector(31 downto 0);
    signal jumpTarget: std_logic_vector(31 downto 0);
    signal writeRegister   : std_logic_vector(4 downto 0);

    -- Pipeline registers
    -- Stage 1 IF/ID
    signal uins_1         : Microinstruction;
    signal instruction_1: std_logic_vector(31 downto 0);
    signal incrementedPC_1: std_logic_vector(31 downto 0);

    -- Stage 2 ID/EX
    signal uins_2: Microinstruction;
    signal instruction_2: std_logic_vector(31 downto 0);
    signal incrementedPC_2: std_logic_vector(31 downto 0);

    signal writeRegister_2: std_logic_vector(4 downto 0);
    signal readData1_2, readData2_2: std_logic_vector(31 downto 0);
    signal signExtended_2: std_logic_vector(31 downto 0);

    signal rs_2, rt_2: std_logic_vector(4 downto 0);

    -- Stage 3 EX/MEM
    signal uins_3: Microinstruction;
    signal instruction_3: std_logic_vector(31 downto 0);
    signal incrementedPC_3: std_logic_vector(31 downto 0);

    signal writeRegister_3: std_logic_vector(4 downto 0);
    signal readData2_3: std_logic_vector(31 downto 0);
    signal result_3: std_logic_vector(31 downto 0);
    signal signExtended_3: std_logic_vector(31 downto 0);

    signal zero_3: std_logic;
    -- Stage 4 MEM/WB
    signal uins_4: Microinstruction;
    signal instruction_4: std_logic_vector(31 downto 0);
    
    signal writeRegister_4: std_logic_vector(4 downto 0);
    signal result_4: std_logic_vector(31 downto 0);
    signal data_i_4: std_logic_vector(31 downto 0);
    
    signal zero_4: std_logic;
    -- Dependency signal for data hazard detection
    signal forward_a: std_logic_vector(1 downto 0);
    signal forward_b: std_logic_vector(1 downto 0);

    signal Hazard: std_logic;
    signal data_dependency: std_logic;
    signal pc_ce: std_logic;

    signal reset_taken_stages: std_logic_vector(1 downto 0);
    signal reset_taken_stages_sync: std_logic_vector(1 downto 0);


    -- Retrieves the rs field from the instruction
    alias rs: std_logic_vector(4 downto 0) is instruction_1(25 downto 21);
        
    -- Retrieves the rt field from the instruction
    alias rt: std_logic_vector(4 downto 0) is instruction_1(20 downto 16);
        
    -- Retrieves the rd field from the instruction
    alias rd: std_logic_vector(4 downto 0) is instruction_1(15 downto 11);
    
    signal zero : std_logic; 

    -- Testes
    alias rs_0: std_logic_vector(4 downto 0) is instruction(25 downto 21);
    alias rt_0: std_logic_vector(4 downto 0) is instruction(20 downto 16);
    alias rd_0: std_logic_vector(4 downto 0) is instruction(15 downto 11);
    signal bypass: std_logic_vector(1 downto 0);
    signal readData1_1_bypass, readData2_1_bypass: std_logic_vector(31 downto 0);
    
begin

    -- IncrementedPC points the next instruction address
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
            ce          => data_dependency, 
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
    SHIFT_L: branchOffset <= signExtended_3(29 downto 0) & "00";
    
    -- Branch target address
    -- Branch ADDER
    ADDER_BRANCH: branchTarget <= STD_LOGIC_VECTOR(UNSIGNED(incrementedPC_3) + UNSIGNED(branchOffset));
    
    -- Jump target address
    jumpTarget <= incrementedPC_3(31 downto 28) & instruction_3(25 downto 0) & "00";
    
    -- MUX which selects the PC value
    -- Threats the jump and branches that are in sequence in the code
    MUX_PC: pc_d <= branchTarget when (uins_3.Branch and zero_3) = '1' and not(uins_4.Jump = '1') else 
                    jumpTarget when uins_3.Jump = '1' and not(uins_4.Jump = '1') and not((uins_4.Branch and zero_4) = '1') else
                    incrementedPC;

    -- Flush the pipeline when a branch is taken
    MUX_RESET_STAGES: reset_taken_stages <= "01" when (((uins_3.Branch and zero_3) = '1') or uins_3.Jump = '1') and not(uins_4.Jump = '1') and not((uins_4.Branch and zero_4) = '1') else
                                             "00";

    -- Selects the ALU operands
    -- MUXes at the ALU input
    MUX_ALU_1: ALUoperand1 <=  readData1_2 when (forward_a = "00") else
                                writeData when (forward_a = "01") else
                                result_3;
                                 
    MUX_ALU_2: ALUoperand2 <= ALUoperand2_mono when (forward_b = "00") else
                                writeData when (forward_b = "01") else
                                result_3;

    MUX_ALU_MONO: ALUoperand2_mono <= readData2_2 when uins_2.ALUSrc = "00" else
                                        zeroExtended when uins_2.ALUSrc = "01" else
                                        signExtended_2;

    -- Selects the data to be written in the register file
    -- MUX at the data memory output
    -- Write data comes from stage 4 of the pipeline
    MUX_DATA_MEM: writeData <= data_i_4 when uins_4.memToReg = '1' else result_4;

    -- Bypass register write if data dependency is detected
    readData2_1_bypass <= writeData when (writeRegister_4 = rt) and uins_4.RegWrite = '1' else readData2;
        
    bypass <= "10" when (writeRegister_4 = rt) and uins_4.RegWrite = '1' else
            "00";
    
    -- Data to data memory comes from the second read register at register file
    data_o <= readData2_3;
    
    -- ALU output address the data memory
    dataAddress <= result_3;

    uins_out <= uins_3;
    -- Synchronizes the reset signal
    process(clock, reset)
    begin
        if reset = '1' then
            reset_taken_stages_sync <= (others => '0');
        elsif rising_edge(clock) then
            reset_taken_stages_sync <= reset_taken_stages;
        end if;
    end process;

    -- Pipeline stage 1 IF/ID
    stage_1: process(clock, reset)
    begin
        if reset = '1' then
            instruction_1 <= (others => '0');
            incrementedPC_1 <= (others => '0');

        -- If detected a data hazard, creates a bubble in the pipeline
        elsif (rising_edge(clock) and data_dependency = '1' and reset_taken_stages = "00") then
            instruction_1 <= instruction;
            incrementedPC_1 <= incrementedPC;
            uins_1 <= uins;
        end if;
    end process stage_1;
    
    -- Pipeline stage 2 ID/EX
    stage_2: process(clock, reset, Hazard, data_dependency, reset_taken_stages_sync)
    begin
        if  (Hazard = '1' and data_dependency = '0') or reset_taken_stages_sync = "01" or reset = '1' then
            instruction_2 <= (others => '0');
            incrementedPC_2 <= (others => '0');
            
            readData1_2 <= (others => '0');
            readData2_2 <= (others => '0');
            signExtended_2 <= (others => '0');
            writeRegister_2 <= (others => '0');
            rs_2 <= (others => '0');
            rt_2 <= (others => '0');

        elsif rising_edge(clock) then
            uins_2 <= uins_1;
            instruction_2 <= instruction_1;
            incrementedPC_2 <= incrementedPC_1;

            writeRegister_2 <= writeRegister;
            readData1_2 <= readData1;
            readData2_2 <= readData2_1_bypass;
            signExtended_2 <= signExtended;
            rs_2 <= rs;
            rt_2 <= rt;
        end if;
    end process stage_2;

    -- Pipeline stage 3 EX/MEM
    stage_3: process(clock, reset, reset_taken_stages_sync)
    begin
        if reset = '1' or reset_taken_stages_sync = "01" then
            instruction_3 <= (others => '0');
            incrementedPC_3 <= (others => '0');

            writeRegister_3 <= (others => '0');
            readData2_3 <= (others => '0');
            result_3 <= (others => '0');
            signExtended_3 <= (others => '0');
            zero_3 <= '0';

        elsif rising_edge(clock) then
            uins_3 <= uins_2;
            instruction_3 <= instruction_2;
            incrementedPC_3 <= incrementedPC_2;

            writeRegister_3 <= writeRegister_2;
            readData2_3 <= readData2_2;
            signExtended_3 <= signExtended_2;
            result_3 <= result;
            zero_3 <= zero;
        end if;
    end process stage_3;

    -- Pipeline stage 4 MEM/WB
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
            zero_4 <= zero_3;
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
            operand1    => ALUoperand1,
            operand2    => ALUoperand2,
            result      => result,
            zero        => zero,
            operation   => uins_2.instruction
        );

    Forwarding_instance: entity work.ForwardingUnit
        port map (
            clock => clock,
            reset => reset,
            writeRegister_4 => writeRegister_4,
            writeRegister_3 => writeRegister_3,
            rs_2 => rs_2,
            rt_2 => rt_2,
            RegWrite_3 => uins_3.RegWrite,
            RegWrite_4 => uins_4.RegWrite,
            forward_a => forward_a,
            forward_b => forward_b
        );

    Hazard_detection: entity work.HazardDetectionUnit
            port map (
                clock => clock,
                reset => reset,
                memToReg_2 => uins_2.memToReg,
                rt_2 => rt_2,
                rt => rt,
                rs => rs,
                data_dependency => data_dependency,
                Hazard => Hazard
            );
end structural;