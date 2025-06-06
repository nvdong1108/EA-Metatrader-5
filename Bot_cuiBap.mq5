//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#define MAGIC_NUMBER 12345

CTrade trade;
CSymbolInfo symbolInfo;


input int EMA1_Period   = 9;    // Nhập số cây nến EMA 1
input int EMA2_Period   = 21;   // Nhập số cây nến EMA 2 


input double stop_price_unit     = 1.5 ; // số pip SL
input double profit_price_unit   = 4.5 ;// số pip TP
input double price_open_new_order  = 1.5 ; // số pip mở thêm lệnh ngược lại. 

int ema1Handle, ema2Handle;

double LotSizeInitial = 0.05;  // <-- Số lượng lot cho lệnh ban đầu 
double LotSizeHedge  = 0.07;  // <-- Số lượng lot cho lệnh phòng thủ

string orderInitial = "" ; 
string nextOrder =  "" ;  

double  priceOpenInitial = 0 ; 
double  priceOpenHedge = 0 ; 


//+------------------------------------------------------------------+
int OnInit()
{   
   Print("Server time: ", TimeCurrent());
   Print("Market open: ", IsMarketOpen());
   Print("Connection: ", TerminalInfoInteger(TERMINAL_CONNECTED));

   // Tạo handle cho EMA
   ema1Handle  = iMA(_Symbol, PERIOD_M5, EMA1_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema2Handle = iMA(_Symbol, PERIOD_M5, EMA2_Period, 0, MODE_EMA, PRICE_CLOSE);
  
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
      Print("❌  market close ");
      return;
   }
   
   //trade.SetMagicNumber(MAGIC_NUMBER);
   // Kiểm tra đủ dữ liệu chưa
   if (Bars(_Symbol, _Period) < EMA2_Period)
      return;

   double ema1_values[2], ema2_values[2];
   if (CopyBuffer(ema1Handle, 0, 1, 2, ema1_values) <= 0 ||
       CopyBuffer(ema2Handle, 0, 1, 2, ema2_values) <= 0)
   {
      Print("❌  Lỗi khi lấy dữ liệu EMA: ", GetLastError());
      return;
   }
 
   datetime  currentCandleTime = iTime(_Symbol, _Period, 0);
   datetime serverTime = TimeCurrent();
   datetime localTime = TimeLocal();
      
   // Tín hiệu MUA: Trên nến vừa đóng (index 1), EMA9 cắt LÊN EMA21
   // Nghĩa là: (EMA9 ở index 2 < EMA21 ở index 2) VÀ (EMA9 ở index 1 > EMA21 ở index 1)
   bool crossUp = ema1_values[1] > ema2_values[1] && ema1_values[0] < ema2_values[0];

   // Tín hiệu BÁN: Trên nến vừa đóng (index 1), EMA9 cắt XUỐNG EMA21
   // Nghĩa là: (EMA9 ở index 2 > EMA21 ở index 2) VÀ (EMA9 ở index 1 < EMA21 ở index 1)
   bool crossDown = ema1_values[1] < ema2_values[1] && ema1_values[0] > ema2_values[0];
   int openPosition = HasOpenPosition();
   if(openPosition > 0 ){
      
      
      if (orderInitial != "BUY" && orderInitial != "SELL" ){
          Print("❌ : Undefined Order Initial");
          return ;
       }else if (nextOrder != "BUY" && nextOrder != "SELL") {
         Print("❌ : Undefined Next Order");
         return ;
       }
       
       double _lotSize = (orderInitial == nextOrder) ? LotSizeInitial : LotSizeHedge;
       if(orderInitial == "BUY"){
         if(nextOrder == "SELL"){
               double priceSell = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(priceSell <= priceOpenHedge){
                  
                  SendSellOrder(_lotSize,SymbolInfoDouble(_Symbol, SYMBOL_BID));
                  nextOrder = "BUY";
                  
                  Print("*** DCA Order SELL with ",_lotSize, " SUCCESS");
                  Print(" Có tổng ", openPosition , " + 1 Đang mở hiện tại \n");
               }
               // ignore
          } else {
              double priceBuy = SymbolInfoDouble(_Symbol, SYMBOL_ASK);  
              if(priceBuy >= priceOpenInitial ){
                  
                  SendBuyOrder(_lotSize,SymbolInfoDouble(_Symbol, SYMBOL_ASK));
                  nextOrder = "SELL";
                  
                  
                  Print("*** DCA Order BUY with ",_lotSize, " SUCCESS");
                  Print(" Có tổng ", openPosition , " + 1 Đang mở hiện tại \n");
              }
         }
       } else  {//--- Initial == SELL 
         if(nextOrder == "SELL"){
            double priceSell = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if (priceSell<= priceOpenInitial){
                
                SendSellOrder(_lotSize,SymbolInfoDouble(_Symbol, SYMBOL_BID));
                nextOrder = "BUY";
                
                
                Print("*** DCA Order SELL with ",_lotSize, " SUCCESS");
                Print(" Có tổng ", openPosition , " + 1 Đang mở hiện tại \n");
            }
            // ignore
          }else {
             double priceBuy = SymbolInfoDouble(_Symbol, SYMBOL_ASK);  
             if (priceBuy >= priceOpenHedge ){
                  Print(" Có ", openPosition , " Đang mở hiện tại ");
                  SendBuyOrder(_lotSize,SymbolInfoDouble(_Symbol, SYMBOL_ASK));
                  nextOrder = "SELL";
                  
                  Print("*** DCA Order BUY with ",_lotSize, " SUCCESS");
                  Print(" Có tổng ", openPosition , " + 1 Đang mở hiện tại \n");
             }
          }
       }
      return;
   }else {
      priceOpenInitial = 0;
      priceOpenHedge = 0;
      nextOrder = "";
   }
   
 
   
   // Kiểm tra giao cắt
   //if (ema5[1] < ema20[1] && ema5[0] > ema20[0])
   if(crossUp)
   {
      Print("📉 Tín hiệu MUA - EMA5 cắt xuống EMA20");
      double currenPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      SendBuyOrder(LotSizeInitial,currenPrice);
      orderInitial = "BUY";
      nextOrder = "SELL";
      priceOpenInitial = currenPrice;
      priceOpenHedge = currenPrice - stop_price_unit;
      
   } else if (crossDown){
      Print("📈 Tín hiệu BÁN - EMA5 cắt lên EMA20");
      double currenPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      SendSellOrder(LotSizeInitial,currenPrice);
      orderInitial = "SELL";
      nextOrder = "BUY";
      priceOpenInitial = currenPrice;
      priceOpenHedge = currenPrice + stop_price_unit;
      
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

   return true;
}

//+------------------------------------------------------------------+
bool SendBuyOrder(double _lotOrd, double price )
   {
   double sl = price - (stop_price_unit + profit_price_unit); 
   double tp = price + profit_price_unit;
   if (trade.Buy(_lotOrd, _Symbol, price, sl,tp, "EMA Buy")){
         Print("✅ Send buy success!");
         return true ;
   }else{
        Print("❌ Gửi lệnh MUA lỗi: ", GetLastError());
        return false;
   }
}





//+------------------------------------------------------------------+
bool SendSellOrder(double _lotOrd, double price)
{
   double sl = price + (stop_price_unit + profit_price_unit );
   double tp = price - profit_price_unit;
   
   if (trade.Sell(_lotOrd, _Symbol, price, sl, tp, "EMA Sell")){
         Print("✅ ord sell send success!");
         return true;
   }else {
      Print("❌ Gửi lệnh BÁN lỗi: ", GetLastError());
      return false;
   }
}




//+------------------------------------------------------------------+
//| Hàm kiểm tra xem có lệnh đang mở không                           |
//+------------------------------------------------------------------+
int HasOpenPosition()
{
   int openPosition = 0 ;
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) && PositionGetString(POSITION_SYMBOL) == _Symbol){
         openPosition++;
      } 
   }
   return openPosition;
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


