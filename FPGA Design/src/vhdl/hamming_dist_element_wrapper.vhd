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
-- File Name   : hamming_dist_element_wrapper.vhd
-- Author      : Martin Kaiser and Sarah Pilz
-- Description : Wrapper for hamming processing elements. Generates a generic number
--               of HPE and instantiates all needed signals to connect them.
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

library raptor_basetypes;
use raptor_basetypes.pkg_ub_if_types.all;


library hamming_dist;
use hamming_dist.hamming_dist_element_wrapper_pkg.all;

entity hamming_dist_element_wrapper is
  generic(
    SIGNATURE_LENGTH : in integer;
    NUMBER_OF_HAMMING_ELEMENTS  : in integer;
    PIPELINE_STAGES : in integer;
    HAMMING_DIST_LENGTH : in integer
  );
  port(
    CLK_IN                      : in  std_logic;
		CLK_HPE_GATED_IN            : in  std_logic;
    RESET_N_IN                  : in  std_logic;
    PE_RESULTS_OUT              : out  array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS-1);
    PE_RESULTS_VALID_OUT        : out unsigned(NUMBER_OF_HAMMING_ELEMENTS-1 downto 0);
    SIGNATURE_A_IN              : in unsigned(SIGNATURE_LENGTH-1 downto 0);
    SIGNATURE_A_VALID_IN        : in std_logic;
    SIGNATURE_A_IDX_IN          : in unsigned (26 downto 0);
    SIGNATURE_B_IN              : in unsigned(SIGNATURE_LENGTH-1 downto 0);
    SIGNATURE_B_VALID_IN        : in std_logic;
    SIGNATURE_B_IDX_IN          : in unsigned (26 downto 0);
    GLOBAL_ENABLE               : in std_logic
  );
end hamming_dist_element_wrapper;


--------------------
--  ARCHITECTURE  --
--------------------

architecture RTL of hamming_dist_element_wrapper is



  ---------------------------
  --  SIGNAL DECLARATIONS  --
  ---------------------------
  
  signal hamming_dist_out_genl : array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS - 1) := (others => (others => '0'));

  ---idx for signatures
  type idx_signal is array (0 to NUMBER_OF_HAMMING_ELEMENTS-1) of unsigned (26 downto 0);
  signal next_signature_1_idx    : idx_signal;
  signal current_signature_2_idx : idx_signal := (others => (others => '0'));
  signal next_signature_2_idx    : idx_signal;
  
  --array for generic signature lenths
  type array_signature is array (0 to NUMBER_OF_HAMMING_ELEMENTS) of unsigned(SIGNATURE_LENGTH-1 downto 0);
  signal current_signature_A : array_signature := (others => (others => '0'));
  signal next_signature_A : array_signature;
  signal current_signature_B : array_signature := (others => (others => '0'));
  signal next_signature_B    : array_signature;
  
  --valid signals
  signal next_sig_A_valids : unsigned(NUMBER_OF_HAMMING_ELEMENTS downto 0) := (others => '0');
  signal current_sig_B_valids : unsigned(NUMBER_OF_HAMMING_ELEMENTS downto 0) := (others => '0'); 
  signal next_sig_B_valids : unsigned(NUMBER_OF_HAMMING_ELEMENTS downto 0) := (others => '0'); 
  signal hpe_result_valid : unsigned(NUMBER_OF_HAMMING_ELEMENTS-1 downto 0) := (others => '0');
  
  --shift signature A
  signal sig_a_shift : unsigned(NUMBER_OF_HAMMING_ELEMENTS downto 0);-- one more than ncessecary. 

---------
begin  --
---------

  -------------------------------
  --  COMPONENT INSTANTIAIONS  --
  -------------------------------      
  --Generate the generic number of HPE
  H_GENERATE : for i in 0 to NUMBER_OF_HAMMING_ELEMENTS-1 generate
    begin
      H0 : if (i = 0) generate --special case: first element gets inputs directly from the top instance
        begin      
          hamming_dist_elem_inst : entity work.hamming_dist_elem
            generic map(
              SIGNATURE_LENGTH => SIGNATURE_LENGTH,
              PIPELINE_STAGES  => PIPELINE_STAGES,
              HAMMING_DIST_OUT_LENGTH  => HAMMING_DIST_LENGTH  
            )
            port map( 
						  CLK_HPE_GATED_IN          => CLK_HPE_GATED_IN,
              CLK_IN                    => CLK_IN,
              RESET_N_IN                => RESET_N_IN,
              SIG1_IDX_IN               => to_unsigned(i, 27),
              SIG2_IDX_IN               => SIGNATURE_B_IDX_IN,
              SIGNATURE_1_IN            => SIGNATURE_A_IN,
              SIGNATURE_1_SHIFT_IN      => SIGNATURE_A_VALID_IN,
              SIGNATURE_1_OUT           => next_signature_A(0),
              SIGNATURE_1_SHIFT_OUT     => sig_a_shift(i+1),
              SIGNATURE_2_IN            => SIGNATURE_B_IN,
              SIGNATURE_2_OUT           => next_signature_B(i+1),
              SIGNATURE_2_VALID_IN      => SIGNATURE_B_VALID_IN,
              SIGNATURE_2_VALID_OUT     => next_sig_B_valids(i+1),
              HAMMING_DIST_VALID_OUT    => hpe_result_valid(i),
              HAMMING_DIST_OUT          => hamming_dist_out_genl(i),
              GLOBAL_ENABLE             => GLOBAL_ENABLE
            );
      end generate H0;
      
      HX : if (i > 0 and i <= NUMBER_OF_HAMMING_ELEMENTS - 1) generate --all further HPE
        begin
          hamming_dist_elem_inst : entity work.hamming_dist_elem
            generic map(
              SIGNATURE_LENGTH => SIGNATURE_LENGTH,
              PIPELINE_STAGES  => PIPELINE_STAGES,
              HAMMING_DIST_OUT_LENGTH  => HAMMING_DIST_LENGTH
            )
            port map(
						  CLK_HPE_GATED_IN          => CLK_HPE_GATED_IN,
              CLK_IN            => CLK_IN,
              RESET_N_IN        => RESET_N_IN,
              SIG1_IDX_IN               => to_unsigned(i, 27),
              SIG2_IDX_IN               => unsigned(hamming_dist_out_genl(i-1)(36 downto 10)),
              SIGNATURE_1_IN            => current_signature_A(i),
              SIGNATURE_1_SHIFT_IN      => sig_a_shift(i), 
              SIGNATURE_1_OUT           => next_signature_A(i+1),
              SIGNATURE_1_SHIFT_OUT     => sig_a_shift(i+1),
              SIGNATURE_2_IN            => current_signature_B(i),
              SIGNATURE_2_OUT           => next_signature_B(i+1),
              SIGNATURE_2_VALID_IN      => current_sig_B_valids(i),
              SIGNATURE_2_VALID_OUT     => next_sig_B_valids(i+1),
              HAMMING_DIST_VALID_OUT    => hpe_result_valid(i),
              HAMMING_DIST_OUT          =>  hamming_dist_out_genl(i),
              GLOBAL_ENABLE             => GLOBAL_ENABLE
            );
      end generate HX;
      
  end generate H_GENERATE;
      
      
      
  --------------------------------
  --  INPUT/OUTPUT ASSIGNMENTS  --
  --------------------------------
    PE_RESULTS_OUT <= hamming_dist_out_genl;
    PE_RESULTS_VALID_OUT <= hpe_result_valid;
    
  -----------------------------
  --  CONCURRENT STATEMENTS  --
  -----------------------------
    next_signature_A(1) <= current_signature_A(0);
    
  -----------------
  --  PROCESSES  --
  -----------------
 
  hpw_wrapper_reg_p : process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
        current_signature_A <= next_signature_A;
        current_signature_B <= next_signature_B;
      if (RESET_N_IN = '0') then
        current_sig_B_valids <= (others => '0');
        current_signature_2_idx <= (others => (others => '0'));
  else
        current_signature_2_idx <= next_signature_2_idx;
        current_sig_B_valids <= next_sig_B_valids;
      end if;
    end if;
  end process hpw_wrapper_reg_p;

end RTL; 