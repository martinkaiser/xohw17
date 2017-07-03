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
-- File Name   : threshold_checker.vhd
-- Author      : Martin Kaiser and Sarah Pilz
-- Description : Takes an input value and compares it to a generic threshold value
--               values lower than the threshold will be given back
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


library hamming_dist;
use hamming_dist.collector_pkg.all;
use hamming_dist.hamming_dist_element_wrapper_pkg.all; 

--------------
--  ENTITY  --                                                
--------------

entity threshold_checker is
  generic(
    NUMBER_OF_HAMMING_ELEMENTS : in integer;
    THRESHOLD                  : in integer --only results below this threshold will be forwarded
  );
  port(
    CLK_IN                  : in  std_logic;
    RESET_N_IN              : in  std_logic;
    HPE_RESULTS_IN          : in  array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS-1);  --Result value input
    HPE_RESULTS_WR_REQ_IN   : in  unsigned(NUMBER_OF_HAMMING_ELEMENTS-1 downto 0);                      --Write request / enable
    HPE_RESULTS_OUT         : out  array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS-1); --Result value output
    HPE_RESULTS_WR_REQ_OUT  : out  unsigned(NUMBER_OF_HAMMING_ELEMENTS-1 downto 0)                      --Write request forwarded or suppressed
  );
end threshold_checker;


--------------------
--  ARCHITECTURE  --
--------------------

architecture RTL of threshold_checker is

---------------------------
--  SIGNAL DECLARATIONS  --
---------------------------
signal result_debug : std_logic_vector(9 downto 0); --debug signal for simulation usage only

---------
begin  --
---------

process (CLK_IN)
	begin
	  if rising_edge(CLK_IN) then
	    if RESET_N_IN = '0' then
            HPE_RESULTS_WR_REQ_OUT <= (others => '0');
      else
         for i in 0 to NUMBER_OF_HAMMING_ELEMENTS-1 loop
            HPE_RESULTS_OUT(i) <= HPE_RESULTS_IN(i);
            result_debug <= std_logic_vector(to_unsigned(THRESHOLD, HPE_RESULTS_IN(i)(9 downto 0)'length));
            --forward the write request if result value is below the threshold
          if (HPE_RESULTS_IN(i) (9 downto 0) < std_logic_vector(to_unsigned(THRESHOLD, HPE_RESULTS_IN(i)(9 downto 0)'length))) then       
            HPE_RESULTS_WR_REQ_OUT(i) <= HPE_RESULTS_WR_REQ_IN(i);
          else
            HPE_RESULTS_WR_REQ_OUT(i) <= '0';   
          end if;
         end loop;
   end if;
end if;
	end process; 
  
end RTL;  