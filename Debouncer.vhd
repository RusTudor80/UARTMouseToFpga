library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;
USE IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;

entity Debouncer is
    generic ( 
        CLK_NUMBER: integer range 2 to (integer'high) := 2**16
    );
    port ( 
        input: in std_logic;
        clk: in std_logic;
        output: out std_logic
    );
end Debouncer;

architecture Behavioral of Debouncer is

--Determinam cat de mare trebuie sa fie std_logic_vector-ul counterului pentru debounce folosind libraria IEEE.math_real
constant COUNTER_WIDTH: integer := natural(ceil(LOG2(real(CLK_NUMBER))));
--Determinam valoarea cu care va fi comparat numaratorul pentru a trimite semnalul debounsat pe portul de output
constant COUNTER_MAX: std_logic_vector((COUNTER_WIDTH - 1) downto 0) := std_logic_vector(to_unsigned((CLK_NUMBER - 1), COUNTER_WIDTH));
signal counter: std_logic_vector((COUNTER_WIDTH - 1) downto 0):= (others=>'0');
--Semnalul pe care realizam debounceul pentru portul input
signal outputTemp: std_logic:= '0';

begin
    Debouncer: process (clk)
    begin
        if (rising_edge(clk)) then
                if ((outputTemp xor input) = '1') then
                    if (counter = COUNTER_MAX) then
                        counter <= (others => '0');
                    else
                        counter <= counter + 1;
                    end if;
                else
                    counter <= (others => '0');
                end if;
                if (counter = COUNTER_MAX) then
                    outputTemp <= not(outputTemp);
                end if;
        end if;
    end process;

output <= outputTemp;
end Behavioral;

