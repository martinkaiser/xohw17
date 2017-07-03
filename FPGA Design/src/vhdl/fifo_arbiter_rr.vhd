-- Copyright (c) 2014 Grigori Goronzy <greg@kinoho.net>
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
-- File Name   : fifo_arbiter_rr.vhd
-- Author      : Martin Kaiser and Sarah Pilz
-- Description : Arbiter with request and urgent request. A generic number of inputs are
--               handled an permission is given using round robin scheduling.
--
-- Revision History:
--------------------------------------------------------------------------------
--
-- Version | Author                        | Date       | Changes
-----------+-------------------------------+------------+----------------------------
-- 1.0     | Martin Kaiser and Sarah Pilz  | 2017-06-30 | - urgent_request added
-----------+-------------------------------+------------+----------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity arbiterRR is
    Generic ( nports : integer := 4 );
    Port ( reset_n_in         : in STD_LOGIC;
           clk_in             : in STD_LOGIC;
           request_in         : in STD_LOGIC_VECTOR(nports-1 downto 0);
           urgent_request_in  : in STD_LOGIC_VECTOR(nports-1 downto 0);
           grant_out          : out STD_LOGIC_VECTOR(nports-1 downto 0);
           enbale_in          : in STD_LOGIC
         );
end arbiterRR;

architecture Behavioral of arbiterRR is
    -- normal request
    signal grant_q  : STD_LOGIC_VECTOR(nports-1 downto 0) := (others => '0');
    signal pre_req  : STD_LOGIC_VECTOR(nports-1 downto 0);
    signal sel_gnt  : STD_LOGIC_VECTOR(nports-1 downto 0);
    signal isol_lsb : STD_LOGIC_VECTOR(nports-1 downto 0);
    signal mask_pre : STD_LOGIC_VECTOR(nports-1 downto 0);
    signal win      : STD_LOGIC_VECTOR(nports-1 downto 0);
    -- urgent request
    signal pre_req_u  : STD_LOGIC_VECTOR(nports-1 downto 0);
    signal sel_gnt_u  : STD_LOGIC_VECTOR(nports-1 downto 0);
    signal mask_pre_u : STD_LOGIC_VECTOR(nports-1 downto 0);
    signal isol_lsb_u : STD_LOGIC_VECTOR(nports-1 downto 0);
    signal win_u      : STD_LOGIC_VECTOR(nports-1 downto 0);
    signal urgent :std_logic := '0';
begin

    grant_out <= grant_q when enbale_in = '1' else (others => '0'); 
    mask_pre  <= request_in and not (std_logic_vector(unsigned(pre_req) - 1) or pre_req); --mask out previous winner
    sel_gnt   <= mask_pre and std_logic_vector(unsigned(not(mask_pre)) + 1); --select lowest significant bit as new priority
    isol_lsb  <= request_in and std_logic_vector(unsigned(not(request_in)) + 1); --select lowest significant bit as fallback grant_out
    win       <= sel_gnt when mask_pre /= (nports-1 downto 0 => '0') else isol_lsb;
    
    
    mask_pre_u  <= urgent_request_in and not (std_logic_vector(unsigned(pre_req_u) - 1) or pre_req_u); --mask out previous winner
    sel_gnt_u   <= mask_pre_u and std_logic_vector(unsigned(not(mask_pre_u)) + 1); --select lowest significant bit as new priority
    isol_lsb_u  <= urgent_request_in and std_logic_vector(unsigned(not(urgent_request_in)) + 1); --select lowest significant bit as fallback grant_out
    win_u       <= sel_gnt_u when mask_pre_u /= (nports-1 downto 0 => '0') else isol_lsb_u;

    
    urgent <= '1' when  urgent_request_in /= (nports-1 downto 0 => '0') else '0';
    
    
    process
    begin
        wait until rising_edge(clk_in);
        if reset_n_in = '0' then
            pre_req <= (others => '0');
            pre_req_u <= (others => '0');
        elsif enbale_in = '1' then
              pre_req <= pre_req;
              if win /= (nports-1 downto 0 => '0') then
                  pre_req <= win;
              end if;
              pre_req_u <= pre_req_u;
              if win_u /= (nports-1 downto 0 => '0') then
                  pre_req_u <= win_u;
              end if;
            if urgent = '1' then
              grant_q <= win_u;
            else
              grant_q <= win;
        end if;
      end if;
    end process;

end Behavioral;