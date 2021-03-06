//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+


#property version "1.0"
#property copyright ""
#property description ""
#property strict
//+------------------------------------------------------------------+
//| Enumerator of working mode                                       |
//+------------------------------------------------------------------+
enum copier_mode
  {
   master,//Master mode
   slave,//Slave mode
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
extern double stopLoss = 20;//sl (pip) (0 == same sl)
extern double useRiskFactor = 1;//Risk factor(0 == same lot)
input copier_mode mode = 0; // Working mode
input int slip = 10;       // Slippage (in points)

double mult = 1.0;

int
opened_list[500],
            ticket,
            type,
            filehandle;

string
symbol;

double
lot,
price,
sl,
tp,
accBalance;

double newLot = 0;
string masterName = "master";
string slaveName = "master";

datetime CloseTime = D'2015.01.01 00:00',  NY = D'2021.05.05 00:00';
datetime openTime = 0, orderOpenTime = 0;
//+------------------------------------------------------------------+
//|Initialisation function                                           |
//+------------------------------------------------------------------+
void init()
  {
   openTime = TimeCurrent();
   EventSetMillisecondTimer(1);

   return;
  }
//+------------------------------------------------------------------+
//|Deinitialisation function                                         |
//+------------------------------------------------------------------+
void deinit()
  {
   ObjectDelete("eatype");
   EventKillTimer();
   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      Comment("Trade is not allowed");
      return;
     }
   else
      Comment("");
   if(!ObjectFind("eatype") || ObjectDescription("eatype") != EnumToString(mode))
     {
      ObjectDelete("eatype");
      ObjectCreate("eatype",OBJ_LABEL,0,0,0);
      ObjectSet("eatype",OBJPROP_XDISTANCE,10);
      ObjectSet("eatype",OBJPROP_YDISTANCE,10);
      ObjectSet("eatype",OBJPROP_COLOR,Red);
      ObjectSetText("eatype",EnumToString(mode));
      ObjectSet("eatype",OBJPROP_FONTSIZE,10);
     }

//--- Master working mode
   if(EnumToString(mode) == "master")
     {
      //--- Saving information about opened deals
      if(OrdersTotal() == 0)
        {
         filehandle = FileOpen("C4F.csv",FILE_WRITE | FILE_CSV | FILE_COMMON);
         FileWrite(filehandle,"");
         FileClose(filehandle);
        }
      else
        {
         filehandle = FileOpen("C4F.csv",FILE_WRITE | FILE_CSV | FILE_COMMON);

         if(filehandle != INVALID_HANDLE)
           {
            for(int i = 0; i < OrdersTotal(); i++)
              {
               if(!OrderSelect(i,SELECT_BY_POS))
                  break;
               symbol = OrderSymbol();

               if(StringSubstr(OrderComment(),0,3) != "C4F")
                  FileWrite(filehandle,OrderTicket(),symbol,OrderType(),OrderOpenPrice(),OrderLots(),OrderStopLoss(),OrderTakeProfit(), AccountBalance(), OrderOpenTime());
               FileFlush(filehandle);
              }
            FileClose(filehandle);
           }
        }
     }

//--- Slave working mode
   if(EnumToString(mode) == "slave")
     {
      //--- Checking for the new deals and stop loss/take profit changes
      filehandle = FileOpen("C4F.csv",FILE_READ | FILE_CSV | FILE_COMMON);

      if(filehandle != INVALID_HANDLE)
        {
         int o = 0;
         opened_list[o] = 0;

         while(!FileIsEnding(filehandle))
           {
            ticket = StrToInteger(FileReadString(filehandle));

            symbol = (FileReadString(filehandle));
            type = StrToInteger(FileReadString(filehandle));
            price = StrToDouble(FileReadString(filehandle));
            lot = StrToDouble(FileReadString(filehandle)) * mult;
            sl = StrToDouble(FileReadString(filehandle));
            tp = StrToDouble(FileReadString(filehandle));
            accBalance = StrToDouble(FileReadString(filehandle));
            orderOpenTime = StrToTime(FileReadString(filehandle));
            symbol = returnSymbol(symbol);
            string OrdComm = "C4F" + IntegerToString(ticket);

            for(int i = 0; i < OrdersTotal(); i++)
              {
               if(!OrderSelect(i,SELECT_BY_POS))
                  continue;

               if(OrderComment() != OrdComm)
                  continue;

               opened_list[o] = ticket;
               opened_list[o + 1] = 0;
               o++;
               double getCurPoint = getPoint(OrderSymbol()), getCurSpread = MarketInfo(OrderSymbol(), MODE_SPREAD) / 10;
               double newSl = OrderType() == OP_BUY ? stopLoss * - 1 : stopLoss ;
               if(OrderType() > 1 && OrderOpenPrice() != price)
                 {
                  if(!OrderModify(OrderTicket(),price,0,0,0))
                     Print("Error: ",GetLastError()," during modification of the order.");
                 }
               double curSL = OrderStopLoss(), curTP = OrderTakeProfit();
               if((tp != curTP || (sl != curSL && stopLoss == 0) || (stopLoss != 0 && MathAbs(OrderStopLoss() - (OrderOpenPrice() + (newSl * getCurPoint))) >= 1 * MarketInfo(OrderSymbol(), MODE_POINT)))  && GlobalVariableGet((string)OrderTicket()) != 1)
                 {
                  GlobalVariableSet((string)OrderTicket(), 1);
                  if(!OrderModify(OrderTicket(),OrderOpenPrice(),stopLoss == 0 ? sl : (OrderType() == OP_BUY ? OrderOpenPrice() - (stopLoss) * getCurPoint : OrderOpenPrice() + (stopLoss) * getCurPoint),tp,0))
                     Print("Error: ",GetLastError()," during modification of the order.");
                 }
               break;
              }
            bool allow = compare(orderOpenTime, openTime);

            //--- If deal was not opened yet on slave-account, open it.
            if(InList(ticket) == -1 && ticket != 0 //&& ((useRiskFactor != 0 && accBalance != 0) || useRiskFactor == 0) && allow
              )
              {
               if(useRiskFactor != 0)
                  newLot = lot * (AccountBalance() / accBalance * useRiskFactor);
               else
                  newLot = lot;

               FileClose(filehandle);
               if(type < 2)
                  OpenMarketOrder(ticket,symbol,type,price,newLot);
               if(type > 1)
                  OpenPendingOrder(ticket,symbol,type,price,newLot);
               return;
              }
           }
         FileClose(filehandle);
        }
      else
         return;

      //--- If deal was closed on master-account, close it on slave-accont
      for(int i = 0; i < OrdersTotal(); i++)
        {
         if(!OrderSelect(i,SELECT_BY_POS))
            continue;

         if(StringSubstr(OrderComment(),0,3) != "C4F")
            continue;

         if(InList(StrToInteger(StringSubstr(OrderComment(),StringLen("C4F"),0))) == -1)
           {
            if(OrderType() == 0)
              {
               if(!OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),slip))
                  Print("Error: ",GetLastError()," during closing the order.");
              }
            else
               if(OrderType() == 1)
                 {
                  if(!OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),slip))
                     Print("Error: ",GetLastError()," during closing the order.");
                 }
               else
                  if(OrderType() > 1)
                    {
                     if(!OrderDelete(OrderTicket()))
                        Print("Error: ",GetLastError()," during deleting the pending order.");
                    }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getPoint(string getSymbol)
  {
   int digit = (int)MarketInfo(getSymbol, MODE_DIGITS);
   double point  = MarketInfo(getSymbol, MODE_POINT), newPoint = 0;
   newPoint = digit == 3 || digit == 5 ? point * 10 : 100;

   return newPoint;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool compare(datetime time1, datetime time2)
  {
   int year = TimeYear(time1), year2 = TimeYear(time2), hour1 = TimeHour(time1), hour2 = TimeHour(time2), min1 = TimeMinute(time1), min2 = TimeMinute(time2), sec1 = TimeSeconds(time1), sec2 = TimeSeconds(time2);
   if(time1 > time2)
      return true;
   return false;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string returnSymbol(string check)
  {
   string symbolr = "";
   for(int i = 0; i < SymbolsTotal(true); i++)
     {
      string symbolName = SymbolName(i, true);
      if(StringFind(check, symbolName) != -1 && check != "")
        {
         return symbolr = symbolName ;
        }
     }
   return symbolr;
  }
//+------------------------------------------------------------------+
//|Checking list                                                     |
//+------------------------------------------------------------------+
int InList(int ticket_)
  {
   int h = 0;

   while(opened_list[h] != 0)
     {
      if(opened_list[h] == ticket_)
         return(1);
      h++;
     }
   return(-1);
  }
//+------------------------------------------------------------------+
//|Open market execution orders                                      |
//+------------------------------------------------------------------+
void OpenMarketOrder(int ticket_,string symbol_,int type_,double price_,double lot_)
  {
   double market_price = MarketInfo(symbol_,MODE_BID);
   if(type_ == 0)
      market_price = MarketInfo(symbol_,MODE_ASK);

// double delta;
   double MaxLot = MarketInfo(symbol_,MODE_MAXLOT);
   double MinLot = MarketInfo(symbol_,MODE_MINLOT);

   if(lot_ < MinLot)
      lot_ = MinLot;
   if(lot_ > MaxLot)
      lot_ = MaxLot;

//delta=MathAbs(market_price-price_)/MarketInfo(symbol_,MODE_POINT);
// if(delta>slip) return;
   int newType = type_;
   if(!OrderSend(symbol_,newType,LotNormalize(lot_),market_price,slip,0,0,"C4F" + IntegerToString(ticket_)))
      Print("Error: ",GetLastError()," during opening the market order.");
   return;
  }
//+------------------------------------------------------------------+
//|Open pending orders                                               |
//+------------------------------------------------------------------+
void OpenPendingOrder(int ticket_,string symbol_,int type_,double price_,double lot_)
  {
   if(!OrderSend(symbol_,type_,LotNormalize(lot_),price_,slip,0,0,"C4F" + IntegerToString(ticket_)))
      Print("Error: ",GetLastError()," during setting the pending order.");
   return;
  }
//+------------------------------------------------------------------+
//|Normalize lot size                                                |
//+------------------------------------------------------------------+
double LotNormalize(double lot_)
  {
   double minlot = MarketInfo(symbol,MODE_MINLOT);

   if(minlot == 0.001)
      return(NormalizeDouble(lot_,3));
   else
      if(minlot == 0.01)
         return(NormalizeDouble(lot_,2));
      else
         if(minlot == 0.1)
            return(NormalizeDouble(lot_,1));

   return(NormalizeDouble(lot_,0));
  }
//+------------------------------------------------------------------+
