// 定義按鍵位
SETUP_BUTTON    BIT P3.1   // 設定按鈕
INCREMENT_BUTTON BIT P3.0  // 增加按鈕
CONFIRM_BUTTON BIT P3.2    // 確認按鈕
SWITCH_BUTTON BIT P3.3    // 转换按鈕
	
// 定義標誌位
MODE_FLAG      EQU 30H     // 0: 計時狀態 1: 設定時 2: 設定分 3: 設定秒
SWITCH_FLAG		EQU 3AH		;=0表示显示时间，=1表示显示日期
	
// 定義變量
SECONDS        DATA 31H    // 秒計數
MINUTES        DATA 32H    // 分計數
HOURS          DATA 33H    // 時計數
DISPLAY_COUNTER DATA 34H   // 顯示計數器，功能是让数码管熄灭一段时间
DELAY_COUNTER  DATA 35H    // 延遲計數器
YEARH			DATA 39H             ;年份高两位
YEAR 			DATA 38H               ;年份低两位存放单元
MONTH 			DATA 37H            ;月份存放单元
DAY 			DATA 36H                ;日存放单元

// 常量定義
SECONDS_MAX    EQU 60      // 每分鐘最大秒數
MINUTES_MAX    EQU 60      // 每小時最大分鐘數
HOURS_MAX      EQU 24      // 每天最大小時數
DAY_MAX 		EQU 31
MONTH_MAX 		EQU 12
YEAR_MAX		EQU 99
			

// 程序開始地址
ORG 0000H
AJMP MAIN                // 跳轉到 MAIN 標籤

// 定時器中斷地址
ORG 001BH
LJMP TIMER_INTERRUPT     // 跳轉到定時中斷服務程序

// 其他中斷地址（例如外部中斷）
ORG 0045H
MAIN:
	SETB P1.5
    MOV SP, #60H          // 設置堆棧指針初始值
    MOV TMOD, #10H        // 設置定時器1為模式1（16位定時器）
    MOV TH1, #3CH         // 設置定時器1高8位
    MOV TL1, #0B0H        // 設置定時器1低8位，定時50毫秒
    MOV IE, #88H          // 开启全局中断和定時器1中斷
    SETB TR1              // 啟動定時器1
    SETB F0               // 設置標誌位 F0
	MOV YEARH, #14H			//初始化日期
	MOV YEAR, #18H
	MOV MONTH, #06H
	MOV DAY, #07H
MAIN_LOOP:
    LCALL DISPLAY_TIMES         // 調用顯示程序
	LCALL DISPLAY_DATES         // 調用顯示程序
    ACALL SETTING_MODE    // 調用設置程序
    SJMP MAIN_LOOP        // 無限循環

// 定時器中斷服務程序
TIMER_INTERRUPT:
    PUSH ACC              // 保存累加器
    PUSH PSW              // 保存程序狀態字
    MOV TH1, #3CH         // 重設定時器1高8位
    MOV TL1, #0B0H        // 重設定時器1低8位
    INC R7                // 增加 R7 計數
    CJNE R7, #14H, TIMER_INTERRUPT_CONTINUE_M   // 如果 R7 不等於 20（1秒），跳轉到 TIMER_INTERRUPT_CONTINUE
    MOV R7, #00H          // 否則清零 R7
    
    INC SECONDS           ; 增加秒计数
    MOV A, SECONDS        ; 将 SECONDS 的值移动到累加器
    CJNE A, #SECONDS_MAX, TIMER_INTERRUPT_CONTINUE  ; 比较累加器的值与 SECONDS_MAX
    MOV SECONDS, #00H     ; 如果相等，清零秒计数
    INC MINUTES           ; 增加分计数
    MOV A, MINUTES        ; 将 MINUTES 的值移动到累加器
    CJNE A, #MINUTES_MAX, TIMER_INTERRUPT_CONTINUE  ; 比较累加器的值与 MINUTES_MAX
    MOV MINUTES, #00H     ; 如果相等，清零分计数
    INC HOURS             ; 增加小时计数
    MOV A, HOURS          ; 将 HOURS 的值移动到累加器
    CJNE A, #HOURS_MAX, TIMER_INTERRUPT_CONTINUE  ; 比较累加器的值与 HOURS_MAX
    MOV HOURS, #00H       ; 如果相等，清零小时计数
	
	INC DAY
	MOV A,MONTH
	INC A
	MOVC  A,@A+PC
	SJMP  DAY_JUDGEMENT
	DB 31H,28H,31H       ;对应月份编码:01H,02H,03H
	DB 30H,31H,30H       ;对应月份编码:04H,05H,06H
	DB 31H,31H,30H       ;对应月份编码:07H,08H,09H
	DB 31H,30H,31H       ;对应月份编码:0AH,0BH,0CH

DAY_JUDGEMENT:
	CLR   C
	SUBB  A,DAY
	JNC   TIMER_INTERRUPT_CONTINUE                ;本月未满
	MOV   A,MONTH
	CJNE  A,#2,NOT_LEAP       ;不是二月就跳到 NOT_LEAP
	MOV   A,YEAR
	MOV DPL, YEAR
    MOV DPH, YEARH
	
	; 检查是否能被4整除
    MOV A, DPH
    MOV B, #4
    DIV AB
    MOV A, B
    CJNE A, #0, NOT_LEAP

    ; 检查是否能被100整除
    MOV A, DPL
    MOV B, #100
    DIV AB
    MOV A, B
    CJNE A, #0, LEAP

    ; 检查是否能被400整除
	MOV B, #200		;寄存器只能存储 8 位（一个字节）的数据.400无法直接放进去
	ADD A, B
	MOV B, #200
	ADD A, B
    MOV A, DPL
    DIV AB
    MOV A, B
    CJNE A, #0, NOT_LEAP
	
LEAP:
	MOV   A,DAY
	XRL   A,#29H
	JZ    TIMER_INTERRUPT_CONTINUE              ;闰年二月可以有29日
	JNZ		NOT_LEAP
	
TIMER_INTERRUPT_CONTINUE_M:
	JMP TIMER_INTERRUPT_CONTINUE
	
NOT_LEAP:
	MOV   DAY,#1          ;调整到下个月的1日
	INC   MONTH
	MOV A, MONTH          ; 将 MONTH 的值移动到累加器
    CJNE A, #MONTH_MAX, TIMER_INTERRUPT_CONTINUE  ; 比较累加器的值与 MONTH_MAX
    MOV MONTH, #00H       ; 如果相等，清零计数
	INC YEAR
	
TIMER_INTERRUPT_CONTINUE:
    POP PSW               // 恢復程序狀態字
    POP ACC               // 恢復累加器
    RETI                  // 返回主程序

// 顯示程序
DISPLAY_TIMES:
	MOV A,SWITCH_FLAG
	CJNE A,#0,DISPLAY_SECONDS_CONTINUE_M	;SWITCH_FLAG不是0就返回主程序
	
    MOV DPTR, #DIGIT_TABLE // 設置數據指針指向顯示字模表
    INC DISPLAY_COUNTER    // 增加顯示計數器
    MOV A, MODE_FLAG       // 讀取標誌位
    CJNE A, #1, DISPLAY_HOURS  // 如果標誌位不等於 1，跳轉到 DISPLAY_HOURS，即標誌位等於 0 就正常显示
    CLR C
	MOV A, DISPLAY_COUNTER    ; 将 DISPLAY_COUNTER 的值加载到累加器 A 中
	CJNE A, #128, DISPLAY_HOURS_CHECK     // 如果顯示計數器不等於 128，跳轉到 DISPLAY_HOURS_CHECK，顯示計數器没达到128时数码管不显示任何东西，实现了数码管闪烁功能
DISPLAY_HOURS_CHECK:
    JC DISPLAY_HOURS_CONTINUE  // 如果顯示計數器小於 128，跳轉到 DISPLAY_HOURS_CONTINUE
DISPLAY_SECONDS_CONTINUE_M:		;DISPLAY_SECONDS_CONTINUE的中间跳转程序，主要是解决距离太远无法跳转的问题
	JMP DISPLAY_SECONDS_CONTINUE
DISPLAY_HOURS:
    MOV A, HOURS          // 顯示小時
    MOV B, #0AH           // 除以10
    DIV AB
    MOVC A, @A+DPTR       // 從字模表中讀取對應數字
    MOV P0, A             // 輸出高位
    MOV P2, #0FFH
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H
    
    MOV A, B              // 輸出低位
    MOVC A, @A+DPTR
    MOV P0, A
    MOV P2, #0FBH
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H
    
DISPLAY_HOURS_CONTINUE:
    MOV P0, #40H          // 顯示符號 '-'
    MOV P2, #0F7H
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H
    
    MOV A, MODE_FLAG       // 讀取標誌位
    CJNE A, #2, DISPLAY_MINUTES  // 如果標誌位不等於 2，跳轉到 DISPLAY_MINUTES
    CLR C
    MOV A, DISPLAY_COUNTER    ; 将 DISPLAY_COUNTER 的值加载到累加器 A 中
	CJNE A, #128, DISPLAY_MINUTES_CHECK   ; 比较累加器 A 的值与立即数 128  // 如果顯示計數器不等於 128，跳轉到 DISPLAY_MINUTES_CHECK
DISPLAY_MINUTES_CHECK:
    JC DISPLAY_MINUTES_CONTINUE  // 如果顯示計數器小於 128，跳轉到 DISPLAY_MINUTES_CONTINUE
DISPLAY_MINUTES:
    MOV A, MINUTES         // 顯示分
    MOV B, #0AH
    DIV AB
    MOVC A, @A+DPTR
    MOV P0, A
    MOV P2, #0F3H
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H
    
    MOV A, B
    MOVC A, @A+DPTR
    MOV P0, A
    MOV P2, #0EFH
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H
    
DISPLAY_MINUTES_CONTINUE:
    MOV P0, #40H           // 顯示符號 '-'
    MOV P2, #0EBH
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H
    
    MOV A, MODE_FLAG        // 讀取標誌位
    CJNE A, #3, DISPLAY_SECONDS  // 如果標誌位不等於 3，跳轉到 DISPLAY_SECONDS
    CLR C
    MOV A, DISPLAY_COUNTER    ; 将 DISPLAY_COUNTER 的值加载到累加器 A 中
	CJNE A, #128, DISPLAY_SECONDS_CHECK   ; 比较累加器 A 的值与立即数 128  // 如果顯示計數器不等於 128，跳轉到 DISPLAY_SECONDS_CHECK
DISPLAY_SECONDS_CHECK:
    JC DISPLAY_SECONDS_CONTINUE  // 如果顯示計數器小於 128，跳轉到 DISPLAY_SECONDS_CONTINUE
DISPLAY_SECONDS:
    MOV A, SECONDS         // 顯示秒
    MOV B, #0AH
    DIV AB
    MOVC A, @A+DPTR
    MOV P0, A
    MOV P2, #0E7H
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H
    
    MOV A, B
    MOVC A, @A+DPTR
    MOV P0, A
    MOV P2, #0E3H
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H
DISPLAY_SECONDS_CONTINUE:
    RET                    // 返回主程序

; 顯示程序
DISPLAY_DATES:
	MOV A,SWITCH_FLAG
	CJNE A,#1,DISPLAY_DAYS_CONTINUE_M	;SWITCH_FLAG不是1就返回主程序
	JB SWITCH_FLAG,DISPLAY_DATES_CONTINUE	;SWITCH_FLAG是1就跳到DISPLAY_DATES_CONTINUE
DISPLAY_DAYS_CONTINUE_M:		;DISPLAY_DAYS_CONTINUE的中间跳转程序，主要是解决距离太远无法跳转的问题
	JMP DISPLAY_DAYS_CONTINUE
DISPLAY_DATES_CONTINUE:	
    MOV DPTR, #DIGIT_TABLE    ; 設置數據指針指向顯示字模表
	INC DISPLAY_COUNTER    // 增加顯示計數器
    MOV A, MODE_FLAG       // 讀取標誌位
    CJNE A, #1, DISPLAY_YEARS  // 如果標誌位不等於 1，跳轉到 DISPLAY_YEARS，即標誌位等於 0 就正常显示
    CLR C
	MOV A, DISPLAY_COUNTER    ; 将 DISPLAY_COUNTER 的值加载到累加器 A 中
	CJNE A, #128, DISPLAY_YEARS_CHECK     // 如果顯示計數器不等於 128，跳轉到 DISPLAY_YEARS_CHECK，顯示計數器没达到128时数码管不显示任何东西，实现了数码管闪烁功能
DISPLAY_YEARS_CHECK:
    JC DISPLAY_YEARS_CONTINUE  // 如果顯示計數器小於 128，跳轉到 DISPLAY_YEARS_CONTINUE
DISPLAY_YEARS:   
	; 顯示年份高两位
    MOV A, YEARH
    MOV B, #0AH
    DIV AB
    MOVC A, @A+DPTR           ; 取十位
    MOV P0, A                 ; 顯示年份高两位的十位
    MOV P2, #0FFH
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H

    MOV A, B
    MOVC A, @A+DPTR           ; 取个位
    MOV P0, A                 ; 顯示年份高两位的个位
    MOV P2, #0FBH
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H

    ; 顯示年份低两位
    MOV A, YEAR
    MOV B, #0AH
    DIV AB
    MOVC A, @A+DPTR           ; 取十位
    MOV P0, A                 ; 顯示年份低两位的十位
    MOV P2, #0F7H
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H

    MOV A, B
    MOVC A, @A+DPTR           ; 取个位
    MOV P0, A                 ; 顯示年份低两位的个位
    MOV P2, #0F3H
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H
	
DISPLAY_YEARS_CONTINUE:
	MOV A, MODE_FLAG       // 讀取標誌位
    CJNE A, #2, DISPLAY_MONTHS  // 如果標誌位不等於 2，跳轉到 DISPLAY_MONTHS
    CLR C
    MOV A, DISPLAY_COUNTER    ; 将 DISPLAY_COUNTER 的值加载到累加器 A 中
	CJNE A, #128, DISPLAY_MONTHS_CHECK   ; 比较累加器 A 的值与立即数 128  // 如果顯示計數器不等於 128，跳轉到 DISPLAY_MONTHS_CHECK
DISPLAY_MONTHS_CHECK:
    JC DISPLAY_MONTHS_CONTINUE  // 如果顯示計數器小於 128，跳轉到 DISPLAY_MONTHS_CONTINUE
DISPLAY_MONTHS:
    ; 顯示月份
    MOV A, MONTH
    MOV B, #0AH
    DIV AB
    MOVC A, @A+DPTR           ; 取十位
    MOV P0, A                 ; 顯示月份的十位
    MOV P2, #0EFH
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H

    MOV A, B
    MOVC A, @A+DPTR           ; 取个位
    MOV P0, A                 ; 顯示月份的个位
    MOV P2, #0EBH
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H

DISPLAY_MONTHS_CONTINUE:
	MOV A, MODE_FLAG        // 讀取標誌位
    CJNE A, #3, DISPLAY_DAYS  // 如果標誌位不等於 3，跳轉到 DISPLAY_DAYS
    CLR C
    MOV A, DISPLAY_COUNTER    ; 将 DISPLAY_COUNTER 的值加载到累加器 A 中
	CJNE A, #128, DISPLAY_DAYS_CHECK   ; 比较累加器 A 的值与立即数 128  // 如果顯示計數器不等於 128，跳轉到 DISPLAY_DAYS_CHECK
DISPLAY_DAYS_CHECK:
    JC DISPLAY_DAYS_CONTINUE  // 如果顯示計數器小於 128，跳轉到 DISPLAY_DAYS_CONTINUE
DISPLAY_DAYS:
    ; 顯示日期
    MOV A, DAY
    MOV B, #0AH
    DIV AB
    MOVC A, @A+DPTR           ; 取十位
    MOV P0, A                 ; 顯示日期的十位
    MOV P2, #0E7H
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H

    MOV A, B
    MOVC A, @A+DPTR           ; 取个位
    MOV P0, A                 ; 顯示日期的个位
    MOV P2, #0E3H
    DJNZ DELAY_COUNTER, $
    MOV P0, #00H
DISPLAY_DAYS_CONTINUE:
    RET

// 設置程序
SETTING_MODE:
    JB SETUP_BUTTON, SETUP_MODE_0  // 如果 SETUP_BUTTON 按鈕不被按下，跳轉到 SETUP_MODE_0
    JNB SETUP_BUTTON, $            // 等待按鍵擡起
    CLR TR1                        // 停止定時器1
    INC MODE_FLAG                  // 增加標誌位
    MOV A, MODE_FLAG
    CJNE A, #4, SETUP_RETURN_1       // 如果標誌位不等於 4，跳轉到 SETUP_RETURN
    MOV MODE_FLAG, #1              // 否則重置標誌位為1
    LJMP SETUP_RETURN              // 跳轉到 SETUP_RETURN
	
SETUP_MODE_0:
    JB CONFIRM_BUTTON, SETUP_MODE_1 // 如果 CONFIRM_BUTTON 按鈕沒有被按下，跳轉到 SETUP_MODE_1
    JNB CONFIRM_BUTTON, $          // 等待按鍵恢復原始位置
    MOV MODE_FLAG, #0              // 重置標誌位為0
    SETB TR1                       // 重新啟動定時器1
    LJMP SETUP_RETURN              // 跳轉到 SETUP_RETURN
	
SETUP_RETURN_1:	;因为离SETUP_RETURN距离太长，有些指令无法跳转，所以中间插一个跟SETUP_RETURN一样功能的片段
		RET
		
SETUP_MODE_1:
	MOV A, MODE_FLAG
    JZ SETUP_RETURN_1                // 如果標誌位為0，跳轉到 SETUP_RETURN
    JB INCREMENT_BUTTON, SETUP_MODE_2 // 如果 INCREMENT_BUTTON 按鈕沒有被按下，跳轉到 SETUP_RETURN
    JNB INCREMENT_BUTTON, $        // 等待按鍵恢復原始位置
	MOV A, SWITCH_FLAG	
	CJNE A, #1, SETUP_INCREMENT_HOURS // 如果標誌位不等於1，跳轉到 SETUP_INCREMENT_MINUTES
	SJMP SETUP_INCREMENT_YEAR
	
SETUP_INCREMENT_HOURS:
	MOV A, MODE_FLAG
    CJNE A, #1, SETUP_INCREMENT_MINUTES // 如果標誌位不等於1，跳轉到 SETUP_INCREMENT_MINUTES
    INC HOURS                    // 增加時計數
    MOV A, HOURS        ; 将 HOURS 的值移动到累加器
    CJNE A, #HOURS_MAX, SETUP_RETURN // 如果時不等於最大值，跳轉到 SETUP_RETURN
    MOV HOURS, #00H              // 否則清零秒計數
    SJMP SETUP_RETURN              // 跳轉到 SETUP_RETURN
	
SETUP_INCREMENT_MINUTES:
    CJNE A, #2, SETUP_INCREMENT_SECONDS // 如果標誌位不等於2，跳轉到 SETUP_INCREMENT_SECONDS
    INC MINUTES                    // 增加分計數
	MOV A,MINUTES
    CJNE A, #MINUTES_MAX, SETUP_RETURN // 如果分不等於60，跳轉到 SETUP_RETURN
    MOV MINUTES, #00H              // 否則清零分計數
    SJMP SETUP_RETURN              // 跳轉到 SETUP_RETURN
	
SETUP_INCREMENT_SECONDS:
    CJNE A, #3, SETUP_RETURN       // 如果標誌位不等於3，跳轉到 SETUP_RETURN
    INC SECONDS                      // 增加時計數
	MOV A,SECONDS
    CJNE A, #SECONDS_MAX, SETUP_RETURN  // 如果秒不等於60，跳轉到 SETUP_RETURN
    MOV SECONDS, #00H                // 否則清零秒計數
    SJMP SETUP_RETURN              // 跳轉到 SETUP_RETURN
	
SETUP_INCREMENT_YEAR:
    MOV A, MODE_FLAG
    CJNE A, #1, SETUP_INCREMENT_MONTH  ; 如果標誌位不等於1，跳轉到 SETUP_INCREMENT_MONTH
    INC YEAR                           ; 增加年份低两位計數
    MOV A, YEAR                        ; 将 YEAR 的值移动到累加器
    CJNE A, #YEAR_MAX, SETUP_RETURN  ; 如果年低两位不等於最大值，跳轉到 SETUP_RETURN
    MOV YEAR, #00H                     ; 否則清零年份低两位
    INC YEARH                          ; 增加年份高两位計數
    MOV A, YEARH                       ; 将 YEARH 的值移动到累加器
    CJNE A, #YEAR_MAX, SETUP_RETURN  ; 如果年高两位不等於最大值，跳轉到 SETUP_RETURN
    MOV YEARH, #00H                    ; 否則清零年份高两位
    SJMP SETUP_RETURN                  ; 跳轉到 SETUP_RETURN

SETUP_INCREMENT_MONTH:
    CJNE A, #2, SETUP_INCREMENT_DAY  // 如果標誌位不等於2，跳轉到 SETUP_INCREMENT_DAY
    INC MONTH                    // 增加月份計數
    MOV A, MONTH
    CJNE A, #MONTH_MAX, SETUP_RETURN // 如果月不等於最大值，跳轉到 SETUP_RETURN
    MOV MONTH, #01H              // 否則清零月份計數，并设置为1
    SJMP SETUP_RETURN              // 跳轉到 SETUP_RETURN

SETUP_INCREMENT_DAY:
    CJNE A, #3, SETUP_RETURN       // 如果標誌位不等於3，跳轉到 SETUP_RETURN
    INC DAY                      // 增加日期計數
    MOV A, DAY
    CJNE A, #DAY_MAX, SETUP_RETURN  // 如果日期不等於最大值，跳轉到 SETUP_RETURN
    MOV DAY, #01H                // 否則清零日期計數，并设置为1
    SJMP SETUP_RETURN              // 跳轉到 SETUP_RETURN

SETUP_MODE_2:	
	JB SWITCH_BUTTON, SETUP_RETURN  // 如果 SWITCH_BUTTON 按鈕不被按下，跳轉到 SETUP_RETURN
    JNB SWITCH_BUTTON, $            // 等待按鍵擡起
	CPL SWITCH_FLAG					;SWITCH_FLAG 取反
	MOV MODE_FLAG,#00H				;MODE_FLAG清零
	SJMP SETUP_RETURN              // 跳轉到 SETUP_RETURN
SETUP_RETURN:
    RET                            // 返回主程序

// 顯示字模表
DIGIT_TABLE:
    DB 0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f    ;0-9
    END                            // 程序結束

