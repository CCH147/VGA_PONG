library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use IEEE.STD_LOGIC_UNSIGNED.ALL;
  use IEEE.MATH_REAL.all;

entity VGA_Controller is
    Port (
        clk   : in STD_LOGIC;
		reset : in STD_LOGIC;
        btn1  : in STD_LOGIC;
        btn2  : in STD_LOGIC;
        btn3  : in STD_LOGIC;
        btn4  : in STD_LOGIC;
        sw    : in STD_LOGIC;
        hsync : out STD_LOGIC;
        vsync : out STD_LOGIC;
        red   : out STD_LOGIC_VECTOR (3 downto 0);
        green : out STD_LOGIC_VECTOR (3 downto 0);
        blue  : out STD_LOGIC_VECTOR (3 downto 0); -- LED ball
        LED   : out std_logic_vector(7 downto 0)        
             
    );
end VGA_Controller;

architecture Behavioral of VGA_Controller is
    --Type state is ( start,
      --              Rwin,Lwin
        --           );
    --signal win         : state;
    Type mov is ( stop,bounce,
                    left,right
                   );
    signal ballmov : mov;
    -- VGA 640x480 @ 60 Hz timing parameters
    constant hRez        : integer := 640;  -- horizontal resolution (640x480)
    constant hStartSync  : integer := 656;  -- start of horizontal sync pulse
    constant hEndSync    : integer := 752;  -- end of horizontal sync pulse
    constant hMaxCount   : integer := 800;  -- total pixels per line

    constant vRez        : integer := 480;  -- vertical resolution
    constant vStartSync  : integer := 490;  -- start of vertical sync pulse
    constant vEndSync    : integer := 492;  -- end of vertical sync pulse
    constant vMaxCount   : integer := 525;  -- total lines per frame
    constant sp     : integer := 15; --板子移動速度
    signal   rsp     : integer := 3; --乒乓球移動速度
    signal ini :std_logic := '0';
    signal   v_speed  : std_logic := '1';
    signal   h_speed  : std_logic := '1';
    signal   Lscore  : integer := 0;
    signal   Rscore  : integer := 0;
    signal   score   : std_logic_vector(7 downto 0);
    signal hCount : integer := 0;   --掃描計數(水平)
    signal vCount : integer := 0;   --掃描計數(垂直)
    signal xpos1  : integer := 639; --右邊板子x
    signal ypos1  : integer := 220; --右邊板子y
    signal xpos2  : integer := 0;   --左邊板子x
    signal ypos2  : integer := 220; --左邊板子y
	signal ballx  : integer := 320; --乒乓球圓心x
    signal bally  : integer := 240; --乒乓球圓心y
    constant ball_r : integer := 5;
    constant LEFT_BOUND : integer := 0;
    constant RIGHT_BOUND : integer := 640;
    constant UP_BOUND : integer := 0;
    constant DOWN_BOUND : integer := 479;
	signal div    : STD_LOGIC_VECTOR(60 downto 0);
	signal fc     : STD_LOGIC;
    signal fc1     : STD_LOGIC;
    signal re      : STD_LOGIC := '0';
    signal lfsr 	    : std_logic_vector (1 downto 0) := "01";
    signal th         : std_logic_vector(1 downto 0);
    signal feedback 	: std_logic;
    signal io         : integer range 0 to 6;   
    signal rand : std_logic;
    signal randsp : integer;


begin
	process(clk)
	begin
		if reset='1' then 
			div<=(others=>'0');

		elsif rising_edge(clk) then 
			div<=div+1;
		End if;
	end process;
	fc<=div(1);
    fc1<=div(20);
	
    process(fc)
    begin
        if rising_edge(fc) then
            -- Horizontal counter
            if hCount = hMaxCount - 1 then
                hCount <= 0;
                -- Vertical counter
                if vCount = vMaxCount - 1 then
                    vCount <= 0;
                else
                    vCount <= vCount + 1;
                end if;
            else
                hCount <= hCount + 1;
            end if;
        end if;
    end process;
    
    
    lfsr_pr : process (clk) 
    begin
    if (rising_edge(clk)) then
      if (reset = '0') then
        lfsr <= "00";
      else
        lfsr <= lfsr(0) & feedback;
        io <= to_integer(signed(lfsr));
      end if;
    end if;
    end process lfsr_pr;
    randsp <= io + 2;  
    
    process(fc,sw)
    begin 
        if reset = '1' then
            Lscore <= 0;
            Rscore <= 0;
            score <= "00000000";
            ballmov <= stop;
        elsif rising_edge(fc) then
            case ballmov is
                when stop           --靜止狀態
                    ini <= '1';     --初始化為1，球為靜止狀態
                    if (sw = '1') then    
                        ini <= '0'; --按下發球按鈕，球進入跳動(Bounce)狀態
                        ballmov <= bounce;
                    end if;
                when bounce =>
                    if (bally <= (UP_BOUND + ball_r)) then        --球碰到上邊界時，圓心y軸增加
                        v_speed <= '1';            
                    elsif (bally >= (DOWN_BOUND - ball_r)) then   --球碰到下邊界時，圓心y軸減少
                        v_speed <= '0'; 
                    else  
                        v_speed <= v_speed;                       --都無符合條件時，保持原本
                    end if;
                    if (((ballx <= (xpos2 + 15) + ball_r )) and (bally >= ypos2 - 100) and (bally <= ypos2)) then --球圓心+半徑碰到左邊板子x時，球反彈
                        h_speed <= '1';                             
                    elsif (((ballx >= (xpos1 - 15) - ball_r )) and (bally >= ypos1 - 100) and (bally <= ypos1)) then --球圓心+半徑碰到右邊板子x時，球反彈
                        h_speed <= '0'; 
                    elsif (ballx <= (LEFT_BOUND + ball_r) ) then  --球碰到左邊界時，進入右邊得分狀態
                        ballmov <= right;
                    elsif (ballx >= (RIGHT_BOUND - ball_r)) then  --球碰到右邊界時，進入左邊得分狀態
                        ballmov <= left;
                    else  
                        h_speed <= h_speed;                       --都無符合條件時，保持原本
                    end if;
                when right =>
                    if (Rscore >= 3) then --超過3分勝利，並重置分數
                        Lscore <= 0;
                        Rscore <= 0;
                        ballmov <= stop;
                    else
                        Rscore <= Rscore + 1;
                        ballmov <= stop;  --得分後進入靜止狀態，並等待發球
                        
                    --score <= Rscore(3 downto 0) & Lscore(3 downto 0);
                    end if;
                when left =>
                    if(Lscore >= 3) then --超過3分勝利，並重置分數
                        Lscore <= 0;
                        Rscore <= 0;
                        ballmov <= stop;
                    else
                        Lscore <= Lscore + 1;
                        ballmov <= stop;  --得分後進入靜止狀態，並等待發球
                        
                        --score <= Rscore(3 downto 0) & Lscore(3 downto 0);
                    end if;
            end case;    
                   
        end if; 
    end process;

    process(fc1)
    begin
        if rising_edge(fc1) then
             if (v_speed = '0') then
                    bally <= bally - rsp;  
             else 
                    bally <= bally + rsp;
             end if;
             if (h_speed = '1') then
                    ballx <= ballx + rsp;  
             else 
                    ballx <= ballx - rsp;  
             end if;
             if (ini = '1') then
                 ballx <= 320;
                 bally <= 240;
             end if;
        end if;
    end process; 
    --LED <= score;

    process(fc1,btn1,btn2,btn3,btn4)
    begin
            if rising_edge(fc1) then
                if (btn1 = '1' and (ypos1 <= DOWN_BOUND - 15))then  --控制板子往下移動(碰到下邊界則停止)
                    ypos1 <= ypos1 + sp;
                end if;
                if (btn2 = '1' and ((ypos1) >= 100 + 15) ) then     --控制板子往下移動(碰到上邊界則停止)
                    ypos1 <= ypos1 - sp;
                end if;
                if (btn3 = '1' and (ypos2 <= DOWN_BOUND - 15))then  --控制板子往下移動(碰到下邊界則停止)
                    ypos2 <= ypos2 + sp;
                end if;
                if (btn4 = '1' and ((ypos2) >= 100 + 15) ) then     --控制板子往下移動(碰到上邊界則停止)
                    ypos2 <= ypos2 - sp;
                end if;
            end if;
    end process;
    

    -- Generate synchronization signals
    hsync <= '0' when (hCount >= hStartSync and hCount < hEndSync) else '1';
    vsync <= '0' when (vCount >= vStartSync and vCount < vEndSync) else '1';
    
    -- Generate RGB signals
    process(hCount, vCount)
    begin
        red <= "0000";
        green <= "0000";
        blue <= "0000";
		if reset='1' then 
			red <= "0000";
            green <= "0000";
            blue <= "0000";
		end if;
		
        if (hCount < hRez and vCount < vRez) then
                if (hCount >= (xpos2) and hCount <= (xpos2 + 15) and vCount >= (ypos2 - 100) and vCount <= (ypos2) )then        --劃出長15寬100的長方形
                    red <= "1111";  -- Red stripe
                end if;
                if (hCount >= (xpos1 -15) and hCount <= xpos1 and vCount >= (ypos1 - 100) and vCount <= (ypos1) )then           --劃出長15寬100的長方形
                    green <= "1111";
                end if;
                if ( ((hCount - ballx)**2 + (vCount - bally)**2 ) <= (ball_r)**2 )then                                          --劃出圓心(320,240) 半徑ball_r為5的圓
                    blue <= "1111";
                end if;
                if (Lscore >= 1  and hCount >= 20 and hCount <= 25 and vCount >= 425 and vCount <= 430) then                    --計分
                    red <= "1111";
                end if;
                if (Lscore >= 2  and hCount >= (25 + 5 ) and hCount <= (21 + 5 + 5) and vCount >= 425 and vCount <= 430) then   --計分
                    red <= "1111";
                end if;
                if (Lscore >= 3  and hCount >= (21 + 5 + 5 + 5) and hCount <= (21 + 5 + 5 + 5 + 5) and vCount >= 425 and vCount <= 430) then    --計分
                    red <= "1111";
                end if;
                if (Rscore >= 1  and hCount >= 610 and hCount <= 615 and vCount >= 425 and vCount <= 430) then                  --計分
                    green <= "1111";
                end if;
                if (Rscore >= 2  and hCount >= 600 and hCount <= 600 + 5 and vCount >= 425 and vCount <= 430) then              --計分
                    green <= "1111";
                end if;
                if (Rscore >= 3  and hCount >= 590 and hCount <= 595 and vCount >= 425 and vCount <= 430) then                  --計分
                    green <= "1111";
                end if;
    
        else    
            red <= "0000";
            green <= "0000";
            blue <= "0000";
        end if;
    end process;

end Behavioral;
