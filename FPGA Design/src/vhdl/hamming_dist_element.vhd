-- Copyright (c) 2017 Martin Kaiser and Sarah Pilz
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--------------------------------------------------------------------------------
-- CITEC - Center of Excellence Cognitive Interaction Technology
-- Bielefeld University
-- Cognitronics & Sensor Systems
--
-- File Name   : hamming_dist_element.vhd
-- Author      : Martin Kaiser and Sarah Pilz
-- Description : Central calculation unit for hamming distance calculation of 
--               two signatures with generic length. 
--
-- Revision History:
--------------------------------------------------------------------------------
--
-- Version | Author                        | Date       | Changes
-----------+-------------------------------+------------+----------------------------
-- 1.0     | Martin Kaiser and Sarah Pilz  | 2017-06-30 | - initial release
-----------+-------------------------------+------------+----------------------------

-----------------
--  LIBRARIES  --                                                
-----------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;



--------------
--  ENTITY  --                                                
--------------

entity hamming_dist_elem is
  generic(
    SIGNATURE_LENGTH : in integer;       --generic signature length
    PIPELINE_STAGES  : in integer;       --generic pipeline stages to fit timing requirements
    HAMMING_DIST_OUT_LENGTH : in integer --result length without signature indizes
  );
  port(
	  CLK_HPE_GATED_IN          : in  std_logic;
    CLK_IN                    : in  std_logic;
    RESET_N_IN                : in  std_logic;
    SIG1_IDX_IN               : in unsigned (26 downto 0);
    SIG2_IDX_IN               : in unsigned (26 downto 0);
    SIGNATURE_1_IN            : in  unsigned(SIGNATURE_LENGTH-1 downto 0);
    SIGNATURE_1_SHIFT_IN      : in std_logic; 
    SIGNATURE_1_OUT           : out  unsigned(SIGNATURE_LENGTH-1 downto 0);
    SIGNATURE_1_SHIFT_OUT     : out std_logic; 
    SIGNATURE_2_IN            : in  unsigned(SIGNATURE_LENGTH-1 downto 0);
    SIGNATURE_2_VALID_IN      : in std_logic; 
    SIGNATURE_2_OUT           : out unsigned(SIGNATURE_LENGTH-1 downto 0);
    SIGNATURE_2_VALID_OUT     : out std_logic; 
    HAMMING_DIST_VALID_OUT    : out std_logic; 
    HAMMING_DIST_OUT          : out std_logic_vector(63 downto 0); 
    GLOBAL_ENABLE             : in std_logic
 );
end hamming_dist_elem;


--------------------
--  ARCHITECTURE  --
--------------------

architecture RTL of hamming_dist_elem is

  ------------------------------
  --  COMPONENT DECLARATIONS  --
  ------------------------------

  ---------------------------
  --  SIGNAL DECLARATIONS  --
  ---------------------------
  type HAMMING_DIST_CALC_TYPE is array ((PIPELINE_STAGES -1) downto 0) of std_logic_vector(HAMMING_DIST_OUT_LENGTH downto 0);
  signal current_hamming_dist_pipe : HAMMING_DIST_CALC_TYPE := (others =>  (others => '0'));  
  signal current_hamming_dist_valid_pipe : std_logic_vector(PIPELINE_STAGES downto 0) := (others => '0');
  
  signal current_signature_2_in : unsigned(SIGNATURE_LENGTH-1 downto 0);
  signal current_signature_1_in : unsigned(SIGNATURE_LENGTH-1 downto 0);
  signal current_signature_1_valid_in : std_logic := '0';
  
  signal c_xor_result : unsigned(SIGNATURE_LENGTH-1 downto 0) := (others => '0');
  
  signal sig_2_valid_out_mux : std_logic;
  signal hamming_dist_valid_out_mux : std_logic;
  
  -------------------
  -----Functions-----
  -------------------
  
  --generic length xor 
 function gen_length_xor(s : unsigned(SIGNATURE_LENGTH-1 downto 0); t : unsigned(SIGNATURE_LENGTH-1 downto 0)) return unsigned is 
   variable temp : unsigned(SIGNATURE_LENGTH-1 downto 0) := (others => '0');
  begin
     temp := s xor t;
    return temp;
end function gen_length_xor;
  

--Use LUT6 to get number of ones in 6 bit (for FPGA optimized design)
function lookup6(x : unsigned(5 downto 0)) return integer is
  begin
    case x is
        when  "000000" => return 0; -- 0
        when  "000001" => return 1; -- 1
        when  "000010" => return 1; -- 2
        when  "000011" => return 2; -- 3
        when  "000100" => return 1; -- 4
        when  "000101" => return 2; -- 5
        when  "000110" => return 2; -- 6
        when  "000111" => return 3; -- 7
        when  "001000" => return 1; -- 8
        when  "001001" => return 2; -- 9
        when  "001010" => return 2; --10
        when  "001011" => return 3; --11
        when  "001100" => return 2; --12
        when  "001101" => return 3; --13
        when  "001110" => return 3; --14
        when  "001111" => return 4; --15
        when  "010000" => return 1; --16
        when  "010001" => return 2; --17
        when  "010010" => return 2; --18
        when  "010011" => return 3; --19
        when  "010100" => return 2; --20
        when  "010101" => return 3; --21
        when  "010110" => return 3; --22
        when  "010111" => return 4; --23
        when  "011000" => return 2; --24
        when  "011001" => return 3; --25
        when  "011010" => return 3; --26
        when  "011011" => return 4; --27
        when  "011100" => return 3; --28
        when  "011101" => return 4; --29
        when  "011110" => return 4; --30
        when  "011111" => return 5; --31
        when  "100000" => return 1; --32
        when  "100001" => return 2; --33
        when  "100010" => return 2; --34
        when  "100011" => return 3; --35
        when  "100100" => return 2; --36
        when  "100101" => return 3; --37
        when  "100110" => return 3; --38
        when  "100111" => return 4; --39
        when  "101000" => return 2; --40
        when  "101001" => return 3; --41
        when  "101010" => return 3; --42
        when  "101011" => return 4; --43
        when  "101100" => return 3; --44
        when  "101101" => return 4; --45
        when  "101110" => return 4; --46
        when  "101111" => return 5; --47
        when  "110000" => return 2; --48
        when  "110001" => return 3; --49
        when  "110010" => return 3; --50
        when  "110011" => return 4; --51
        when  "110100" => return 3; --52
        when  "110101" => return 4; --53
        when  "110110" => return 4; --54
        when  "110111" => return 5; --55
        when  "111000" => return 3; --56
        when  "111001" => return 4; --57
        when  "111010" => return 4; --58
        when  "111011" => return 5; --59
        when  "111100" => return 4; --60
        when  "111101" => return 5; --61
        when  "111110" => return 5; --62
        when  "111111" => return 6; --63
    when others => return 7; -- illegal for a 6 bits value input!
    
   end case;
    
end function lookup6;  

 --Divide xor in 6 bit parts, lookup number of ones in every part from lookup6 function and add all parts
  function adder_via_lookup(s : unsigned(SIGNATURE_LENGTH-1 downto 0)) return std_logic_vector is 
  variable temp : std_logic_vector(HAMMING_DIST_OUT_LENGTH downto 0) := (others => '0');
  variable helper : unsigned(5 downto 0) := (others => '0');
  variable rest_sig : integer range 0 to SIGNATURE_LENGTH := SIGNATURE_LENGTH;
  begin
   for i in 0 to SIGNATURE_LENGTH/6 loop
      if (rest_sig >= 6) then
         temp := std_logic_vector( unsigned(temp) + lookup6(s((rest_sig-1) downto (rest_sig-6))) );
         rest_sig := rest_sig -6;
      elsif (rest_sig > 0) then
          helper := (others => '0');
          helper(rest_sig - 1 downto 0) := s(rest_sig - 1 downto 0);
          temp := std_logic_vector( unsigned(temp) + lookup6(helper) );
      end if;
   end loop;
    
  return temp;
end function adder_via_lookup;
  
---------
begin  --
---------
   
  --------------------------------
  --  INPUT/OUTPUT ASSIGNMENTS  --
  --------------------------------
    sig_2_valid_out_mux <= current_hamming_dist_valid_pipe(1) when (GLOBAL_ENABLE = '1') else '0';
    hamming_dist_valid_out_mux <= current_hamming_dist_valid_pipe(PIPELINE_STAGES) when (GLOBAL_ENABLE = '1') else '0';
  
    SIGNATURE_1_OUT <= current_signature_1_in;
    SIGNATURE_2_VALID_OUT <= sig_2_valid_out_mux; 
    
              
    HAMMING_DIST_VALID_OUT <= hamming_dist_valid_out_mux; 
    HAMMING_DIST_OUT(9 downto HAMMING_DIST_OUT_LENGTH+1) <= (others => '0');
    HAMMING_DIST_OUT(HAMMING_DIST_OUT_LENGTH downto 0) <= current_hamming_dist_pipe(PIPELINE_STAGES -1);
    HAMMING_DIST_OUT(36 downto 10) <= std_logic_vector(SIG2_IDX_IN);
    HAMMING_DIST_OUT(63 downto 37) <= std_logic_vector(SIG1_IDX_IN);
    
    SIGNATURE_1_SHIFT_OUT <= SIGNATURE_1_SHIFT_IN;
    
  -----------------------------
  --  CONCURRENT STATEMENTS  --
  -----------------------------

  
  -----------------
  --  PROCESSES  --
  -----------------

 ham_reg_p : process(CLK_HPE_GATED_IN, RESET_N_IN)
  begin
     if (RESET_N_IN = '0') then  
				current_hamming_dist_valid_pipe <= (others => '0');       
				current_hamming_dist_pipe <= (others =>  (others => '0'));   
				c_xor_result <= (others => '0');          
    elsif (rising_edge(CLK_HPE_GATED_IN)) then --TODO?
        current_hamming_dist_valid_pipe(0) <= SIGNATURE_2_VALID_IN;
        current_hamming_dist_valid_pipe(PIPELINE_STAGES downto 1) <= current_hamming_dist_valid_pipe(PIPELINE_STAGES-1 downto 0); --changed due to new registerd xor stage 
        current_hamming_dist_pipe(0) <= adder_via_lookup(c_xor_result);
        current_hamming_dist_pipe(PIPELINE_STAGES -1 downto 1) <= current_hamming_dist_pipe(PIPELINE_STAGES-2 downto 0);
        c_xor_result <= gen_length_xor(current_signature_1_in, SIGNATURE_2_IN); --bei SIGNATURE_1_IN haben 0 und 1 HPE selben inhalt.. bei current stimmt alles.--
			
      SIGNATURE_2_OUT <= current_signature_2_in; --doof ne?  -- TODO eigenes signal udn port concurrent zuweisen
      current_signature_2_in <= SIGNATURE_2_IN;  
      current_signature_1_in <= current_signature_1_in;   
      
      if(SIGNATURE_1_SHIFT_IN = '1') then 
        current_signature_1_in <= SIGNATURE_1_IN;  
      end if;     
    end if;
  end process ham_reg_p;

end RTL;  

  
