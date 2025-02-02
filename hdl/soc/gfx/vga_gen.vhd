--
-- Module modified by Colin "domipheus" Riley, original header below.
-- Populates a fifo which is used to generate a prefetch set of signals if
-- required.
--
----------------------------------------------------------------------------------
-- Engineer:       Mike Field <hamster@snap.net.nz>
-- Module Name:    ColourTest - Behavioral 
-- Description:    Generates an 1280x720x60Hz VGA timing
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity vga_gen is
    generic (
        hRez       : natural := 1280;    
        hStartSync : natural := 1280+72;
        hEndSync   : natural := 1280+72+80;
        hMaxCount  : natural := 1280+72+80+216;
        hsyncActive : std_logic := '0';
        
        vRez       : natural := 720;
        vStartSync : natural := 720+3;
        vEndSync   : natural := 720+3+5;
        vMaxCount  : natural := 720+3+5+22;
        vsyncActive : std_logic := '1';
        prefetch_idx:natural := 8
    );
    Port ( 
        pixel_clock     : in std_logic;
        
        pixel_h : out STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
        pixel_v : out STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
        
        pixel_h_pref : out STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
        pixel_v_pref : out STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
        blank_pref : OUT std_logic;
        
        blank   : out STD_LOGIC := '0';
        hsync   : out STD_LOGIC := '0';
        vsync   : out STD_LOGIC := '0'
    );
end vga_gen;

architecture Behavioral of vga_gen is
   type reg is record
      hCounter : std_logic_vector(11 downto 0);
      vCounter : std_logic_vector(11 downto 0);
      red      : std_logic_vector(7 downto 0);
      green    : std_logic_vector(7 downto 0);
      blue     : std_logic_vector(7 downto 0);
      hSync    : std_logic;
      vSync    : std_logic;
      blank    : std_logic;		
   end record;

   signal r : reg := ((others=>'0'), (others=>'0'),
                      (others=>'0'), (others=>'0'), (others=>'0'), 
                      '0', '0', '1');
   signal n : reg;   
	
   type regqueue is array (15 downto 0) of reg;
	
   signal queue: regqueue := (others=> ((others=>'0'), (others=>'0'),
                      (others=>'0'), (others=>'0'), (others=>'0'), 
                      '0', '0', '1') );
begin
    -- Assign the outputs
    hsync <= queue(15).hSync;
    vsync <= queue(15).vSync;
    
    pixel_h <= queue(15).hCounter;
    pixel_v <= queue(15).vCounter;
    blank <= queue(15).blank;
    
    pixel_h_pref <= queue(prefetch_idx).hCounter;
    pixel_v_pref <= queue(prefetch_idx).vCounter;
    blank_pref <= queue(prefetch_idx).blank;
    
    process(queue(0),n)
    begin
        n <= queue(0);
        n.hSync <= not hSyncActive;      
        n.vSync <= not vSyncActive;      
        
        -- Count the lines and rows      
        if queue(0).hCounter = hMaxCount-1 then
            n.hCounter <= (others => '0');
            if queue(0).vCounter = vMaxCount-1 then
                n.vCounter <= (others => '0');
            else
                n.vCounter <= queue(0).vCounter + 1; 
            end if;
        else
            n.hCounter <= queue(0).hCounter + 1; 
        end if;
        
        if queue(0).hCounter  < hRez and queue(0).vCounter  < vRez then
            n.red   <= n.hCounter(5 downto 0) & n.hCounter(5 downto 4);
            n.green <= n.hCounter(7 downto 0);
            n.blue  <= n.vCounter(7 downto 0);
            n.blank <= '0';
        else
            n.red   <= (others => '0');
            n.green <= (others => '0');
            n.blue  <= (others => '0');
            n.blank <= '1';
        end if;
    
        -- Are we in the hSync pulse?
        if queue(0).hCounter >= hStartSync and queue(0).hCounter < hEndSync then
            n.hSync <= hSyncActive;
        end if;
        
        -- Are we in the vSync pulse?
        if queue(0).vCounter >= vStartSync and queue(0).vCounter < vEndSync then
            n.vSync <= vSyncActive; 
        end if;
    end process;

    process(pixel_clock,n)
    begin
        if rising_edge(pixel_clock)
        then
            queue(15 downto 1) <= queue(14 downto 0);
            queue(0) <= n;
        end if;
    end process;
end Behavioral;