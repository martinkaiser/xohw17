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
-- File Name   : collector_pkg.vhd
-- Author      : Martin Kaiser and Sarah Pilz
-- Description : Package for generic range user defined typed that are needed 
--               for the collector unit.
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

--------------
--  ENTITY  --
--------------

package collector_pkg is

  ------------------------
  --       TYPES        --
  ------------------------

  
  type HPE_STAGE_COUNTING is array (natural range <>) of integer;
  
  type array_col_fifo_128 is array (natural range <>) of std_logic_vector(127 downto 0); --usage: INCOMING_PE_RESULTS     : in  array_pefifo_inoutputs_genlength(0 to NUMBER_OF_HAMMING_ELEMENTS-1);
  type array_col_fifo_64 is array (natural range <>) of std_logic_vector(63 downto 0); 
  type array_ctrlsignals is array (natural range <>) of std_logic;

  type array_col_fifo_128_current is array (0 to 40 - 1) of std_logic_vector(127 downto 0);  

 end package collector_pkg;
  
package body collector_pkg is

end package body;
  
  