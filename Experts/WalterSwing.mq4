//+------------------------------------------------------------------+
//|                                                  WalterSwing.mq4 |
//|                                  Mark Fletcher for Walter Peters |
//|                                            http://www.fxjake.com |
//+------------------------------------------------------------------+
#property copyright "Mark Fletcher for Walter Peters"
#property link      "http://www.fxjake.com"

#include <stderror.mqh>

#define VERSION 0.2

#define MAGICNO 20130723

#define WAIT_FOR_CLOSE 1
#define MANAGE_TRADE 2


// VERSION 0.1 -- initial version
// VERSION 0.2 -- bug fixes on entries, and added email sending capability

// Side -- 0 for sell, 1 for buy 
extern int Side = 1;
// LookBackBars -- number of bars for lookback period 
extern int LookBackBars = 8;
// EntryCushion -- number of pips below / above candle low to place entry order (0 means enter at market)
extern double EntryCushion = 3.0;
// StopCushion -- number of pips above / below swing high / low to place stoploss. 0 means enter at market 
extern double StopCushion = 3.0;
// ProfitMultiplier -- take profit is placed this multiplier times the number of pips risked.
extern double ProfitMultiplier = 3.0;
// EntryFilterPips -- don't take trades if stop would be this number of pips or more away from the entry
extern double EntryFilterPips = 30;
// RiskPercent -- amount to risk in percent for each trade ie 2.0 means 2 percent
extern double RiskPercent = 2;
// DoEmail -- True if should send an email, False if not. Note email must be set up in platform for this to work
extern bool DoEmail = true;

int currentState;
datetime currentBarTime;
double extremeStore;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
   currentState = WAIT_FOR_CLOSE;
   currentBarTime = 0;
   extremeStore = 0;
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
  int lookBack;
  double extremePrice;
  int extremeShift;
  double triggerPrice;
  int startOfDay;
  bool done = false;
//----
   if (currentBarTime == 0)
   {
      currentBarTime = Time[0];
   }
   
   if (Time[0] > currentBarTime)
   {
      // new bar just completed
      currentBarTime = Time[0];
      
      while (!done)
      {
         switch (currentState)
         {
            case WAIT_FOR_CLOSE:
            
               if (haveAPosition())
               {
                  currentState = MANAGE_TRADE;
                  done = false;
               }
               else
               {
            
                  
                  // we are interested in knowing how many bars into the day we are
                  startOfDay = iBarShift(Symbol(), 0, iTime(Symbol(), PERIOD_D1, 0), true);
                  // startOfDay is now either -1 or the index of the first hourly bar of the day.
                  if (startOfDay == -1)
                  {
                   // can't use this day, because the first bar is missing, either from the hourly price feed or from th daily price feed. So we are screwed.
                     //Print ("Could not get a sensible time stamp for the start of the day");
                     return(0);
                  }
      
                  
                  //Print ("Time stamp of start of day is ", TimeToStr(Time[startOfDay], TIME_DATE | TIME_MINUTES), " and that was ", startOfDay, " bars ago");
                  // ok now we know startOfDay is the index of the first bar of the day.
                  if (startOfDay > LookBackBars)
                  {
                     // we are more than LookBackBars into the day, so use the full LookBack
                     lookBack = LookBackBars;
                  }
                  else
                  {
                     lookBack = startOfDay;
                  }
      
                  //Print ("We are looking back ", lookBack, " bars for an extreme. Timestamp of the first bar we will consider is ", TimeToStr(Time[lookBack], TIME_DATE | TIME_MINUTES));
                  if (Side == 1)
                  {
                     // Buy
                     extremeShift = iLowest(Symbol(), 0, MODE_LOW, lookBack, 1);
                     extremePrice = Low[extremeShift];
                     triggerPrice = High[extremeShift];
                     //Print ("we found the extreme ", extremeShift, " bars ago, at timestamp ", TimeToStr(Time[extremeShift], TIME_DATE | TIME_MINUTES), ", extreme price is ", extremePrice, " and trigger Price is ", triggerPrice);
                     if (extremePrice != extremeStore)
                     {
                        clearWaitingOrders();
                     }
                     extremeStore = extremePrice;
                     if (Close[1] > triggerPrice && !haveWaitingOrder())
                     {
                        // Get an order on
                        makeOrder(High[1], extremePrice);
                     }
                  }
                  else
                  {
                     // Sell
                     extremeShift = iHighest(Symbol(), 0, MODE_HIGH, lookBack, 1);
                     extremePrice = High[extremeShift];
                     triggerPrice = Low[extremeShift];
                     //Print ("we found the extreme ", extremeShift, " bars ago, at timestamp ", TimeToStr(Time[extremeShift], TIME_DATE | TIME_MINUTES), ", extreme price is ", extremePrice, " and trigger Price is ", triggerPrice);
                     if (extremePrice != extremeStore)
                     {
                        clearWaitingOrders();
                     }
                     extremeStore = extremePrice;
                     if (Close[1] < triggerPrice && !haveWaitingOrder())
                     {
                        // get an order on
                        makeOrder(Low[1], extremePrice);
                     }
                  }
            
                  done = true;
               }
               break;
            
            case MANAGE_TRADE:
               if (!haveAPosition())
               {
                  currentState = WAIT_FOR_CLOSE;
               }
               else 
               {
                  done = true;
               }
            
         } // end of switch
      } // enf of while !done
   }
//----
   return(0);
  }
//+------------------------------------------------------------------+

double priceToPips(double priceLevel)
{
   double pips = 0;
   
   pips = priceLevel / (Point * 10.0);
   
   return(NormalizeDouble(pips, 1));
}

double pipsToPrice(double pips)
{
   double priceLevel = 0;
   
   priceLevel = pips * (Point * 10.0);
   
   return(NormalizeDouble(priceLevel, Digits));
}

bool lockForTrading()
{
     //if (activePositions != 0) return (false);
     //---- try to lock common resource
     while(!IsStopped())
       {
        //---- locking
        if(GlobalVariableSetOnCondition("TRADE_SEM",1,0)==true)  break;
        //---- may the variable be deleted?
        if(GetLastError()==ERR_GLOBAL_VARIABLE_NOT_FOUND) return(false);
       
        //---- sleeping
        Sleep(500);
       }
     //---- resource locked
     return(true);

}

void releaseForTrading()
{
     //---- unlock resource
     GlobalVariableSet("TRADE_SEM",0);
}

void clearWaitingOrders()
{
   int numPosns;
   int i;
   int ticket = 0;
   
   if (lockForTrading())
   {
      numPosns = OrdersTotal();
      for (i = 0; i < numPosns; i++) 
      {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         
         if (OrderSymbol() != Symbol()) continue;
         
         if (OrderMagicNumber() != MAGICNO)  continue;
         
         if (OrderType() != OP_BUYSTOP && OrderType() != OP_SELLSTOP)   continue;
         
         ticket = OrderTicket();
         break;
      }
      
      if (ticket != 0)
      {
         OrderDelete(ticket);
      }
      
      releaseForTrading();
   }
}

void makeOrder(double trigger, double extreme)
{
   double entry;
   double stop;
   double target;
   double lots;
   string mailText;
      
   if (!lockForTrading())
   {
      return;
   }
   
   if (Side == 1)
   {
      // Buy
      if (EntryCushion == 0)
      {
         entry = Ask;
         stop = extreme - pipsToPrice(StopCushion);
         if (priceToPips(entry - stop) < EntryFilterPips)
         {
            // OK to place trade at market
            target = entry + (entry - stop) * ProfitMultiplier;
            lots = calculateLots(entry, stop);
            //Print("Entry is at Ask, stop is ", stop, ", target is ", target, ", lots is ", lots);
            OrderSend(Symbol(), OP_BUY, lots, Ask, 50, NormalizeDouble(stop, Digits), NormalizeDouble(target, Digits), "WALTERSWING", MAGICNO);
            mailText = StringConcatenate("Just placed a long MARKET order, entry at ", Ask, " stop at ", stop, " target at ", target);
            if (DoEmail && !IsTesting())
            {
               SendMail("WalterSwing Trade Update", mailText);
            }
            else
            {
               Print (mailText);            
            }
         }
      }
      else
      {
         entry = trigger + pipsToPrice(EntryCushion) + (Ask - Bid);
         stop = extreme - pipsToPrice(StopCushion);
         if (priceToPips(entry - stop) < EntryFilterPips)
         {
            // OK to place trade at market
            target = entry + (entry - stop) * ProfitMultiplier;
            lots = calculateLots(entry, stop);
            //Print("Entry is at ", NormalizeDouble(entry, Digits), ", stop is ", stop, ", target is ", target, ", lots is ", lots);
            OrderSend(Symbol(), OP_BUYSTOP, lots, NormalizeDouble(entry, Digits), 50, NormalizeDouble(stop, Digits), NormalizeDouble(target, Digits), "WALTERSWING", MAGICNO);
            mailText = StringConcatenate("Just placed a long ENTRY order, entry at ", entry, " stop at ", stop, " target at ", target);
            if (DoEmail && !IsTesting())
            {
               SendMail("WalterSwing Trade Update", mailText);
            }
            else
            {
               Print (mailText);            
            }
            
         }
         
      }
   }
   else if (Side == 0)
   {
      //Sell
      if (EntryCushion == 0)
      {
         entry = Bid;
         stop = extreme + pipsToPrice(StopCushion) + (Ask - Bid);
         if (priceToPips(stop - entry) < EntryFilterPips)
         {
            // OK to place trade at market
            target = entry - (stop - entry) * ProfitMultiplier;
            lots = calculateLots(entry, stop);
            OrderSend(Symbol(), OP_SELL, lots, Bid, 50, NormalizeDouble(stop, Digits), NormalizeDouble(target, Digits), "WALTERSWING", MAGICNO);
            mailText = StringConcatenate("Just placed a short MARKET order, entry at ", Bid, " stop at ", stop, " target at ", target);
            if (DoEmail && !IsTesting())
            {
               SendMail("WalterSwing Trade Update", mailText);
            }
            else
            {
               Print (mailText);            
            }
         }
      }
      else
      {
         entry = trigger - pipsToPrice(EntryCushion);
         stop = extreme + pipsToPrice(StopCushion) + (Ask - Bid);
         if (priceToPips(stop - entry) < EntryFilterPips)
         {
            // OK to place trade at market
            target = entry - (stop - entry) * ProfitMultiplier;
            lots = calculateLots(entry, stop);
            OrderSend(Symbol(), OP_SELLSTOP, lots, NormalizeDouble(entry, Digits), 50, NormalizeDouble(stop, Digits), NormalizeDouble(target, Digits), "WALTERSWING", MAGICNO);
            mailText = StringConcatenate("Just placed a short ENTRY order, entry at ", entry, " stop at ", stop, " target at ", target);
            if (DoEmail && !IsTesting())
            {
               SendMail("WalterSwing Trade Update", mailText);
            }
            else
            {
               Print (mailText);            
            }
         }
         
      }
      
   }
   
   releaseForTrading();
}

double calculateLots(double entry, double stop)
{
   //lots = riskMoney / pipCost * Point / riskPips;
   // pipCost is MODE_TICKVALUE in MarketInfo function
   
   double lots;
   double pipCost;
   double riskPips;
   double riskMoney;
   
   riskMoney = AccountBalance() * RiskPercent / 100.0;
   
   if (entry > stop)
   {
      riskPips = entry - stop;
   }
   else 
   {
      riskPips = stop - entry;
   }
   
   pipCost = MarketInfo(Symbol(), MODE_TICKVALUE);
   
   lots = NormalizeDouble((riskMoney / pipCost) * (Point / riskPips), 2);
   //Print("Want to trade ", lots, "lots");
   return(lots);
}

bool haveAPosition()
{
   bool havePos = false;
   int numPosns;
   int i;
   
   if (!lockForTrading())
   {
      return (false);
   }
  
   numPosns = OrdersTotal();
   
   for (i = 0; i < numPosns; i++)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      if (OrderSymbol() != Symbol()) continue;
      
      if (OrderMagicNumber() != MAGICNO)  continue;
         
      if (OrderType() != OP_BUY && OrderType() != OP_SELL)   continue;
     
      havePos = true;
      break;
   }
   
   
   releaseForTrading();
   
   return(havePos);
}

bool haveWaitingOrder()
{
   bool havePos = false;
   int numPosns;
   int i;
   
   if (!lockForTrading())
   {
      return (false);
   }
  
   numPosns = OrdersTotal();
   
   for (i = 0; i < numPosns; i++)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      if (OrderSymbol() != Symbol()) continue;
      
      if (OrderMagicNumber() != MAGICNO)  continue;
         
      if (OrderType() != OP_BUYSTOP && OrderType() != OP_SELLSTOP)   continue;
     
      havePos = true;
      break;
   }
   
   
   releaseForTrading();
   
   return(havePos);

}

