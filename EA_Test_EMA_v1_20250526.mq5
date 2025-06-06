//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#define MAGIC_NUMBER 12345

CTrade trade;
CSymbolInfo symbolInfo;


input int EMA1_Period   = 9;    // Nhập số cây nến EMA 1
input int EMA2_Period   = 21;   // Nhập số cây nến EMA 2 
input int MAX_Period    = 21;   // nhập số cây nến tối đa đường EMA

input double stop_price_unit   = 3 ;   //số giá chênh lêch cắt lỗ

input bool is_move_sl = true;

int ema1Handle, ema2Handle;



double globalLotSize = 0.01;  // <-- Đổi tên biến toàn cục

int TP_Count = 0;
int SL_Count = 0;


//+------------------------------------------------------------------+
int OnInit()
{   
   Print("Server time: ", TimeCurrent());
   Print("Market open: ", IsMarketOpen());
   Print("Connection: ", TerminalInfoInteger(TERMINAL_CONNECTED));

   // Tạo handle cho EMA
   ema1Handle  = iMA(_Symbol, PERIOD_M1, EMA1_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema2Handle = iMA(_Symbol, PERIOD_M1, EMA2_Period, 0, MODE_EMA, PRICE_CLOSE);
   // Thiết lập màu sắc cho các đường EMA
   ChartIndicatorAdd(0, 0, ema1Handle);
   ChartIndicatorAdd(0, 0, ema2Handle);
   
   // Thiết lập màu sắc (phải làm sau khi thêm vào biểu đồ)
   ObjectSetInteger(0, "EMA9", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, "EMA21", OBJPROP_COLOR, clrOrangeRed);
   if (ema1Handle == INVALID_HANDLE || ema2Handle == INVALID_HANDLE)
      {
         Print("❌ Không thể tạo handle cho EMA");
         return(INIT_FAILED);
      }

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsMarketOpen()){
      // market close;
      return;
   }
   
   //trade.SetMagicNumber(MAGIC_NUMBER);
   // Kiểm tra đủ dữ liệu chưa
   if (Bars(_Symbol, _Period) < MAX_Period)
      return;

   double ema1_values[4], ema2_values[10];
   if (CopyBuffer(ema1Handle, 0, 1, 10, ema1_values) <= 0 ||
       CopyBuffer(ema2Handle, 0, 1, 10, ema2_values) <= 0)
   {
      Print("❌  Lỗi khi lấy dữ liệu EMA: ", GetLastError());
      return;
   }
 
   datetime  currentCandleTime = iTime(_Symbol, _Period, 0);
   datetime serverTime = TimeCurrent();
   datetime localTime = TimeLocal();
      
   // Tín hiệu MUA: Trên nến vừa đóng (index 1), EMA9 cắt LÊN EMA21
   // Nghĩa là: (EMA9 ở index 2 < EMA21 ở index 2) VÀ (EMA9 ở index 1 > EMA21 ở index 1)
   bool crossUp = ema1_values[1] < ema2_values[1] && ema1_values[0] > ema2_values[0];

   // Tín hiệu BÁN: Trên nến vừa đóng (index 1), EMA9 cắt XUỐNG EMA21
   // Nghĩa là: (EMA9 ở index 2 > EMA21 ở index 2) VÀ (EMA9 ở index 1 < EMA21 ở index 1)
   bool crossDown = ema1_values[1] > ema2_values[1] && ema1_values[0] < ema2_values[0];

   if(HasOpenPosition()){
      //1 . kiểm tra nếu lệnh đang lời 200% kéo SL đến giá vào lệnh để không bị lỗ. 
      if(is_move_sl){
         CheckAndMoveSL();
      } return;
   }
   
 
   
   // Kiểm tra giao cắt
   //if (ema5[1] < ema20[1] && ema5[0] > ema20[0])
   if(crossUp)
   {
      Print("📉 Tín hiệu MUA - EMA5 cắt xuống EMA20");
      SendBuyOrder();
      
   } else if (crossDown){
      Print("📈 Tín hiệu BÁN - EMA5 cắt lên EMA20");
      SendSellOrder();
      
   }
}

bool IsMarketOpen()
{
   // Kiểm tra kết nối
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      return false;

   // Kiểm tra trạng thái thị trường
   if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE))
      return false;

   // Kiểm tra khung giờ giao dịch
   datetime now = TimeCurrent();
   if(now >= D'2025.05.12 22:00' && now < D'2025.05.12 23:00')
      return false;

   return true;
}

//+------------------------------------------------------------------+
void SendBuyOrder()
   {
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = price - stop_price_unit  ; 
   double tp1 = price + (stop_price_unit * 2) ;
   double tp2 = price + (stop_price_unit * 4) ;
   
   double tp = is_move_sl ? tp2 : tp1;
   
   if (trade.Buy(globalLotSize, _Symbol, price, sl,tp, "EMA Buy"))
      Print("✅ Lệnh MUA đã gửi thành công");
   else
      Print("❌ Gửi lệnh MUA lỗi: ", GetLastError());
}
//+------------------------------------------------------------------+
void SendSellOrder()
{
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = price + stop_price_unit; 
   double tp1 = price - (stop_price_unit * 2);
   double tp2 = price - (stop_price_unit * 4);
   
   double tp = is_move_sl ? tp2 : tp1;
   
   if (trade.Sell(globalLotSize, _Symbol, price, sl, tp, "EMA Sell"))
      Print("✅ Lệnh BÁN đã gửi thành công");
   else
      Print("❌ Gửi lệnh BÁN lỗi: ", GetLastError());
}


//+------------------------------------------------------------------+
//| Hàm kiểm tra xem có lệnh đang mở không                           |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) && PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
   }
   return false;
}


//+------------------------------------------------------------------+
//| Hàm kiểm tra và di chuyển SL về entry khi đạt 200% lợi nhuận    |
//+------------------------------------------------------------------+
void CheckAndMoveSL()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(!PositionSelectByTicket(ticket))
         continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                            
      if  (posType == POSITION_TYPE_BUY) {
         double tp1 = entryPrice + (stop_price_unit * 2 ) ;
         if(currentPrice >= tp1 ){
            if(currentSL < entryPrice ){
               double newSL  = entryPrice + 0.1 ;
               if(!trade.PositionModify(ticket, newSL, currentTP))
                  Print("❗ Lỗi khi di chuyển SL (BUY): ", GetLastError());
               else
                  Print("✅ Đã di chuyển SL về entry cho lệnh (BUY) #", ticket);
               
            }
         
         }
      }else {
         double tp1 = entryPrice - (stop_price_unit * 2 ) ;
         if(currentPrice <= tp1 ){
            if(currentSL > entryPrice){
               // move SL 
               double newSL  = entryPrice - 0.1 ;
               if(!trade.PositionModify(ticket, newSL, currentTP))
                  Print("❗ Lỗi khi di chuyển SL (SELL): ", GetLastError());
               else
                  Print("✅ Đã di chuyển SL về entry cho lệnh (SELL) #", ticket);
            }
         }
      }
      
   }
}



bool IsOpenSell()
{
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i))
      {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            return true;
         }
      }
   }
   return false;
}



bool IsOpenBuy()
{
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i))
      {
         if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
             PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            return true;
         }
      }
   }
   return false;
}


//+------------------------------------------------------------------+
//| Hàm kiểm tra lệnh đóng do TP/SL                                  |
//+------------------------------------------------------------------+
void CheckCloseReason()
  {
   HistorySelect(0, TimeCurrent()); // Load lịch sử lệnh
   int total = HistoryDealsTotal(); // Tổng số deal

   for(int i = total - 1; i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
        {
         // Kiểm tra nguyên nhân đóng lệnh
         long close_reason = HistoryDealGetInteger(ticket, DEAL_REASON);
         
         if(close_reason == DEAL_REASON_SL)
           {
            SL_Count++;
           }
         else if(close_reason == DEAL_REASON_TP)
           {
            TP_Count++;
           }
        }
     }
  }
  void OnTradeTransaction(const MqlTradeTransaction& trans) {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      ENUM_DEAL_REASON reason = HistoryDealGetInteger(trans.deal, DEAL_REASON);
      if(reason == DEAL_REASON_SL) SL_Count++;
      if(reason == DEAL_REASON_TP) TP_Count++;
   }
}
  
  //+------------------------------------------------------------------+
//| Hiển thị kết quả sau backtest                                    |
//+------------------------------------------------------------------+
void OnTester()
  {
   CheckCloseReason();
   Print("TP Count: ", TP_Count);
   Print("SL Count: ", SL_Count);
   
   // Xuất ra file CSV (tùy chọn)
   string filename = "Backtest_Result.csv";
   FileDelete(filename);
   int handle = FileOpen(filename, FILE_WRITE | FILE_CSV);
   if(handle != INVALID_HANDLE)
     {
      FileWrite(handle, "TP_Count", "SL_Count");
      FileWrite(handle, TP_Count, SL_Count);
      FileClose(handle);
     }
  }
//+------------------------------------------------------------------+