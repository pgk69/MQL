//+------------------------------------------------------------------+
//|                                           SimpleStartTrading.mq4 |
//|                                                  Martin Bartosch |
//|                                          http://fx.bartosch.name |
//+------------------------------------------------------------------+
#property copyright "Martin Bartosch"
#property link      "http://fx.bartosch.name"
#property version   "1.00"
#property strict

// maximum acceptable distance to original signal
input double MaxGoodSlippage = 100;
input double MaxBadSlippage = 5;
input int MaxSignalAge = 180;
input int SignalExpiration = 1800;
input double DefaultSL = 30;
input double DefaultTP = 30;
input double OrderSize = 0.01;
input int MagicNumber = 9999;
input string url="http://fx.bartosch.name/start-signal.csv";

int TickCount = 0;
datetime LastProcessedSignal = 0;
uchar sep = ';';

extern int Debug = 5;

//--- Global variables
int ticket;
   
//--- Includes
#include <ToolBox.mqh>


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  debugLevel(Debug);
  return(INIT_SUCCEEDED);
}
  
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
}
  
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
  if (! IsTradeAllowed()) return;
  
  if (TickCount++ % 5 == 0) {
    string cookie=NULL;
    string headers;
    char post[];
    char result[];

    int res;
    
    //--- for working with server you need to add "https://www.google.com/finance" 
    //--- to the list of the allowed URLs (Main menu->Tools->Options, "Expert Advisors" tab)
    //--- reset last error
    ResetLastError();
    
    //--- load html page from Google Finance
    int timeout=500; //--- timeout less than 1000 (1 sec.) is not sufficient for slow Internet speed
    res=WebRequest("GET", url, cookie, NULL, timeout, post, 0, result, headers);
    
    //--- check errors
    if(res==-1) debug(3, StringConcatenate("Error code =", GetLastError()));
    else {
      //--- successful
      debug(2, StringConcatenate("Download successful, size =", ArraySize(result), " bytes."));
      //--- save data to file
      string csv = CharArrayToString(result);
      debug(2, StringConcatenate("Returned string: ", csv));
      
      // example string: "DAX Short;9786;9815;9757;2015;01;13;10;15"
      string signal[];
      StringSplit(csv, sep, signal);
      debug(2, StringConcatenate("entry 0: ", signal[0], "  1: ", signal[1], "  2: ", signal[2], "  3: ", signal[3], "  4: ", signal[4], "  5: ", signal[5], "  6: ", signal[6], "  7: ", signal[7], "  8: ", signal[8]));
      
      MqlDateTime SignalTimestamp;
      SignalTimestamp.year = StrToInteger(signal[4]);
      SignalTimestamp.mon  = StrToInteger(signal[5]);
      SignalTimestamp.day  = StrToInteger(signal[6]);
      SignalTimestamp.hour = StrToInteger(signal[7]);
      SignalTimestamp.min  = StrToInteger(signal[8]);
      SignalTimestamp.sec  = 0;
      
      datetime signaltimestamp_epoch = StructToTime(SignalTimestamp);
      // compute age of signal, it must not be older than 2 minutes
      long signalage = TimeLocal() - signaltimestamp_epoch;
      
      if (signalage > MaxSignalAge) {
        debug(1, StringConcatenate("Signal is ", signalage, " seconds old - ignoring"));
        debugLevel(0);
        return;
      } else debugLevel(Debug);

      if (LastProcessedSignal == signaltimestamp_epoch) {
        // signal has already been processed, ignore
        debug(1, StringConcatenate("signal: ", LastProcessedSignal, " has already been processed, ignore"));
        return;
      }
      // all checks OK, let's mark this signal as processed
      // perform sanity checks
      // process the signal
      LastProcessedSignal = signaltimestamp_epoch;
      debug(1, StringConcatenate("Signal: ", LastProcessedSignal, " stored"));
      
      double SignalPrice    = StrToDouble(signal[1]);
      double SignalSL       = StrToDouble(signal[2]);
      double SignalTP       = StrToDouble(signal[3]);
      double Price;
      int ExecuteType;
      datetime Expiration;
      if (StringCompare("DAX Long", signal[0]) == 0) {
        Price = Ask;
        ExecuteType = OP_BUY;
        Expiration = 0;
        if ((MaxGoodSlippage < fmod(SignalPrice-Price, 100)) || (fmod(Price-SignalPrice, 100) > MaxBadSlippage)) {
          debug(1, StringConcatenate("Ignoring signal, current price ", Price, " has moved too far away from Signal price", SignalPrice));
          ExecuteType = OP_BUYLIMIT;
          Expiration = TimeLocal() + SignalExpiration;
        }

        // assign sane defaults if delivered SL/TP are not plausible        
        if (SignalSL < Price - (DefaultSL + 10)) SignalSL = Price - DefaultSL;
        if (SignalTP > Price + (DefaultTP + 10)) SignalTP = Price + DefaultTP;
          
        ticket = OrderSend(Symbol(), ExecuteType, OrderSize, Price, 3, SignalSL, SignalTP, "Start Trading", MagicNumber, Expiration, clrNONE);
        debug(1, StringConcatenate("Order RC:", ticket, " Order: OrderSend(", Symbol(), ", ", ExecuteType, ", ", OrderSize, ", ", Price, ", 3, ", SignalSL, ", ", SignalTP,", Start Trading, ", MagicNumber, ", ", Expiration, ", ", clrNONE, ")"));
      }
      if (StringCompare("DAX Short", signal[0]) == 0) {
        Price = Bid;
        ExecuteType = OP_SELL;
        Expiration = 0;
        if ((MaxBadSlippage < fmod(SignalPrice-Price, 100)) || (fmod(Price-SignalPrice, 100) > MaxGoodSlippage)) {
          debug(1, StringConcatenate("Ignoring signal, current price ", Price, " has moved too far away from Signal price", SignalPrice));
          ExecuteType = OP_SELLLIMIT;
          Expiration = TimeLocal() + SignalExpiration;
        }

        // assign sane defaults if delivered SL/TP are not plausible        
        if (SignalSL > Price + (DefaultSL + 10)) SignalSL = Price + DefaultSL;
        if (SignalTP < Price - (DefaultTP + 10)) SignalTP = Price - DefaultTP;
          
        ticket = OrderSend(Symbol(), ExecuteType, OrderSize, Price, 3, SignalSL, SignalTP, "Start Trading", MagicNumber, Expiration, clrNONE);
        debug(1, StringConcatenate("Order RC:", ticket, " Order: OrderSend(", Symbol(), ", ", ExecuteType, ", ", OrderSize, ", ", Price, ", 3, ", SignalSL, ", ", SignalTP,", Start Trading, ", MagicNumber, ", ", Expiration, ", ", clrNONE, ")"));
       }
    }
  }   
}//+------------------------------------------------------------------+
