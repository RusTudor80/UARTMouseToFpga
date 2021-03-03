
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity UartTxCtrl is
    port ( 
        send : in  STD_LOGIC;
        data : in  STD_LOGIC_VECTOR (7 downto 0);
        clk : in  STD_LOGIC;
        ready : out  STD_LOGIC;
        uartTx : out  STD_LOGIC
    );
end UartTxCtrl;

architecture Behavioral of UartTxCtrl is


--Timerul pentru mentinerea boud rate-ului
constant BIT_TIMER_MAX: std_logic_vector(13 downto 0) := "10100010110000"; --10416 = (100_000 / 9600)
signal bitTimer: std_logic_vector(13 downto 0) := (others => '0');

--Bitul transmis pe linia UART
signal txBit: std_logic := '1';

--Registrul care preia datele de pe portul data si le trimite, prin txBit pe linia UART
constant BIT_INDEX_MAX: natural := 10;
signal txData: std_logic_vector(9 downto 0);
signal bitIndex: natural;

--Semnalul de stare al automatului
type TX_STATE is (RDY, LOAD_BIT, SEND_BIT);
signal txState : TX_STATE := RDY;

begin

--Save data on input port to register buffer
BufferRegister: process (clk)
begin
	if (rising_edge(clk)) then
		if (send = '1') then
			txData <= '1' & data & '0';
		end if;
	end if;
end process;

--Control stari automat
StateControl: process (clk)
begin
	if (rising_edge(clk)) then
		case txState is 
		when RDY =>
			if (send = '1') then
				txState <= LOAD_BIT;
			end if;
		when LOAD_BIT =>
			txState <= SEND_BIT;
		when SEND_BIT =>
			if (bitTimer = BIT_TIMER_MAX) then
				if (bitIndex = BIT_INDEX_MAX) then
					txState <= RDY;
				else
					txState <= LOAD_BIT;
				end if;
			end if;

		end case;
	end if;
end process;

--Control semnale automat
SignalControl: process(clk)
begin
    if rising_edge(clk) then
        case txState is 
        when RDY =>
            bitTimer <= (others => '0');
            bitIndex <= 0;
            txBit <= '1';
        when LOAD_BIT =>
            if (bitTimer = BIT_TIMER_MAX) then
                bitTimer <= (others => '0');
            else
                bitTimer <= bitTimer + 1;
            end if;
            bitIndex <= bitIndex + 1;
            txBit <= txData(bitIndex);
        when SEND_BIT => 
            if (bitTimer = BIT_TIMER_MAX) then
                bitTimer <= (others => '0');
            else
                bitTimer <= bitTimer + 1;
            end if;
        end case;
	end if;
end process;

uartTx <= txBit;
ready <= '1' when (txState = RDY) else '0';

end Behavioral;

