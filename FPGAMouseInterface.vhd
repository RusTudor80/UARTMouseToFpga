-----------------------------------------------------Comunicatia dintre placa Nexys 4 DDR si un mouse USB HID------------------------------------------------------------------------

-- Aplicatia hardware dezvoltata permite comunicarea placii Basys3 cu un mouse de tip PS2 si 
-- transmiterea datelor primite de la mouse la calculator prin intermediul portului UART.
-- Asadar, prin intermediul aplicatiei GUI cu care vine insotita aplicatia VHDL se poate observa
-- ca la un eveniment de tip CLICK al butoanelor LEFT si RIGHT ale mouse-ului se trimit spre
-- receiverul datelor de pe portul UART date precum butonul mouse-ului care a fost apasat si
-- pozitia mouse-ului in momentul CLICK-ului(atat coordonate scrise cat si reprezentarea lor
-- cu ajutorul patratului rosu prezent).

-- Studenti: Risa Alexandru & Rus Tudor
-- Profesor: Dr. ing. Cristi Mocan
-- Institutie: Universitatea Tehnica din Cluj-Napoca
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity FPGAMouseInterface is
    Port (
           rst: in  STD_LOGIC;
           clk: in  STD_LOGIC;
           uartTxd: out  STD_LOGIC;
           mouseClk: inout STD_LOGIC;
           mouseData: inout STD_LOGIC
	);
end FPGAMouseInterface;

architecture Behavioral of FPGAMouseInterface is
-------------------------------------------------------------------------------- Semnale placa --------------------------------------------------------------------------------------
signal rstDebounced: std_logic:= '0';

-------------------------------------------------------------------------------- Semnale mouse --------------------------------------------------------------------------------------
signal lmbDebounced: STD_LOGIC:= '0';
signal rmbDebounced: STD_LOGIC:= '0';
signal lmb: std_logic;
signal rmb: std_logic;
signal mXPos: std_logic_vector (11 downto 0);
signal mYPos: std_logic_vector (11 downto 0);






-------------------------------------------------------------- Semnale pentru transmiterea datelor pe portul UART -------------------------------------------------------------------
--Array de octeti pentru a putea memora cuvinte intr-un semnal
type CHAR_ARRAY is array (integer range<>) of std_logic_vector(7 downto 0);
constant MAX_STR_LEN: integer:= 35;
--String click stanga.                   B      u      t      t      o      n             m      o      u      s      e             l      e      f      t      \n     \r 														  
constant LMB_STR: CHAR_ARRAY(0 to 18):= (X"42", X"75", X"74", X"74", X"6F", X"6E", X"20", X"6D", X"6F", X"75", X"73", X"65", X"20", X"6C", X"65", X"66", X"74", X"0A", X"0D");
constant LMB_STR_LEN: natural:= 19;
--String click dreapta.                  B      u      t      t      o      n             m      o      u      s      e             r      i      g      h       t     \n     \r
constant RMB_STR: CHAR_ARRAY(0 to 19):= (X"42", X"75", X"74", X"74", X"6F", X"6E", X"20", X"6D", X"6F", X"75", X"73", X"65", X"20", X"72", X"69", X"67", X"68", X"74", X"0A", X"0D"); 
constant RMB_STR_LEN: natural:= 20;

--Stringul transmis pe portul UART
signal sendStr : CHAR_ARRAY(0 to (MAX_STR_LEN - 1));

signal strEnd : natural;

signal strIndex : natural;

--Semnale pentru componenta UartTxCtrl
signal uartRdy : std_logic;
signal uartSend : std_logic := '0';
signal uartData : std_logic_vector (7 downto 0):= "00000000";

--Semnal stare Uart
type UART_STATE is (WAIT_BTN, LD_BTN_STR, SEND_CHAR, RDY_LOW, WAIT_RDY);
signal state : UART_STATE := WAIT_BTN;

begin
--------------------------------------------------------------------------- Componente debounce -----------------------------------------------------------------------------------
--Debounce la butonul de rst de pe placa BTNC
rstDebouncer_Comp: entity WORK.Debouncer
    generic map( 
        clk_number => (2**16),
        data_width => 1
    )
    port map( 
        input(0) => rst,
        clk => clk,
        output(0) => rstDebounced
    );
    
--Debounce la left mouse button
LmbDebouncer_Comp: entity WORK.Debouncer 
    generic map(
        clk_number => (2**16),
        data_width => 1)
    port map(
		input(0) => lmb,
		clk => clk,
		output(0) => lmbDebounced
	);

--Debounce la right mouse button
RmbDebouncer_Comp: entity WORK.Debouncer 
    generic map(
        clk_number => (2**16),
        data_width => 1)
    port map(
		input(0) => rmb,
		clk => clk,
		output(0) => rmbDebounced
	);



------------------------------------------------------------------------------- Control stari ---------------------------------------------------------------------------------
--Control stari automat
StateControl: process (clk)
begin
	if (rising_edge(clk)) then
		if (rstDebounced = '1') then
			state <= WAIT_BTN;
		else	
			case state is 
            when WAIT_BTN =>
				if (lmbDebounced='1' or rmbDebounced='1') then
					state <= LD_BTN_STR;
				end if;
			when LD_BTN_STR =>
				state <= SEND_CHAR;
			when SEND_CHAR =>
				state <= RDY_LOW;
			when RDY_LOW =>
				state <= WAIT_RDY;
			when WAIT_RDY =>
				if (uartRdy = '1') then
					if (strEnd = strIndex) then
					    --un fel de debounce aici pt a nu inregistra eveneturile de tip repeat(cand se tine apasat mai mult timp click-ul)
					    if (lmbDebounced='0' and rmbDebounced='0') then
						    state <= WAIT_BTN;
						else
						    state <= WAIT_RDY;
						end if;
					else
						state <= SEND_CHAR;
					end if;
				end if;
			end case;
		end if ;
	end if;
end process;

---------------------------------------------------------------------- Comunicarea pe portul UART ------------------------------------------------------------------------------
--Se scriu semnalele care vor fi transmise componentei de control UART
StringLoad: process (clk)
begin
	if (rising_edge(clk)) then
		if (state = LD_BTN_STR and lmbDebounced='1') then
			sendStr(0) <= mXPos(11 downto 4);
			sendStr(1) <= mXPos(3 downto 0) & "0000";
			sendStr(2) <= mYPos(11 downto 4);
			sendStr(3) <= mYPos(3 downto 0) & "0000"; 
			sendStr(4 to LMB_STR_LEN + 3) <= LMB_STR;
			strEnd <= LMB_STR_LEN + 4;
	    elsif (state = LD_BTN_STR and rmbDebounced='1') then
	        sendStr(0) <= mXPos(11 downto 4);
			sendStr(1) <= mXPos(3 downto 0) & "0000";
			sendStr(2) <= mYPos(11 downto 4);
			sendStr(3) <= mYPos(3 downto 0) & "0000"; 
			sendStr(4 to RMB_STR_LEN + 3) <= RMB_STR;
			strEnd <= RMB_STR_LEN + 4;
		end if;
	end if;
end process;

--Incrementam strIndex pentru a trimite pe rand caracterele spre componenta de control UART
CharCount: process (clk)
begin
	if (rising_edge(clk)) then
		if (state = LD_BTN_STR) then
			strIndex <= 0;
		elsif (state = SEND_CHAR) then
			strIndex <= strIndex + 1;
		end if;
	end if;
end process;

--Se incarca carcaterul in componenta de control a portului UART cand ajungem in starea SEND_CHAR
CharLoad: process (clk)
begin
	if (rising_edge(clk)) then
		if (state = SEND_CHAR) then
			uartSend <= '1';
			uartData <= sendStr(strIndex);
		else
			uartSend <= '0';
		end if;
	end if;
end process;

--Componenta folosita pentru controlul transmisiei pe portul UART
UartTxCtrl_Comp: entity WORK.UartTxCtrl 
    port map (
		send => uartSend,
		data => uartData,
		clk => clk,
		ready => uartRdy,
		uartTx => uartTxd 
	);


-------------------------------------------------------------------- Comunicarea cu mouse-ul ps2 ---------------------------------------------------------------------------
MouseCtl_Comp: entity WORK.MouseCtl
    generic map (
       SYSCLK_FREQUENCY_HZ => 108000000,
       CHECK_PERIOD_MS     => 500,
       TIMEOUT_PERIOD_MS   => 100
    )
    port map (
          clk            => clk,
          rst            => '0',
          xpos           => mXPos,
          ypos           => mYPos,
          zpos           => open,
          left           => lmb,
          middle         => open,
          right          => rmb,
          new_event      => open,
          value          => x"000",
          setx           => '0',
          sety           => '0',
          setmax_x       => '0',
          setmax_y       => '0',
          ps2_clk        => mouseClk,
          ps2_data       => mouseData
    );

end Behavioral;
