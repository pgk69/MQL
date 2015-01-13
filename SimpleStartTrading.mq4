//+------------------------------------------------------------------+
//|                                           SimpleStartTrading.mq4 |
//|                                                  Martin Bartosch |
//|                                          http://fx.bartosch.name |
//+------------------------------------------------------------------+
#property copyright "Martin Bartosch"
#property link      "http://fx.bartosch.name"
#property version   "1.00"
#property strict

int TickCount = 0;

datetime LastProcessedSignal = 0;

// maximum acceptable distance to original signal
input double MaxSlippage = 5;
input int MaxSignalAge = 180;
input double DefaultSL = 30;
input double DefaultTP = 30;
input double OrderSize = 0.1;
input int MagicNumber = 9999;
input string url="http://fx.bartosch.name/start-signal.csv";


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
  uchar sep = ';';
  
  if (TickCount++ % 20 == 0) {
   Alert("20. Tick");
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
   if(res==-1)
     {
      Alert("Error code =",GetLastError());
     }
   else
     {
      //--- successful
      // PrintFormat("Download successful, size =%d bytes.",ArraySize(result));
      //--- save data to file
      string csv = CharArrayToString(result);
      // Alert("Returned string: ", csv);
      
      // example string: "DAX Short;9786;9815;9757;2015;01;13;10;15"
      string signal[];
      StringSplit(csv, sep, signal);
      // Alert("entry 0: ", signal[0]);
      
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
        Print("Signal is ", signalage, " seconds old - ignoring");
        return;
      }

      if (LastProcessedSignal == signaltimestamp_epoch) {
        // signal has already been processed, ignore
        return;
      }
      // all checks OK, let's mark this signal as processed
      // perform sanity checks
      // process the signal
      LastProcessedSignal = signaltimestamp_epoch;
      
      double SignalPrice = StrToDouble(signal[1]);
      double SignalSL    = StrToDouble(signal[2]);
      double SignalTP    = StrToDouble(signal[3]);
      if (StringCompare("DAX Long", signal[0]) == 0) {
        double Price = Ask;
        if ( (Price + MaxSlippage < SignalPrice) || (Price - MaxSlippage > SignalPrice) ) {
          Print("Ignoring signal, current price ", Price, " has moved too far away from Signal price", SignalPrice);
          return;
        }

        // assign sane defaults if delivered SL/TP are not plausible        
        if (SignalSL < Price - (DefaultSL + 10))
          SignalSL = Price - DefaultSL;
          
        if (SignalTP > Price + (DefaultTP + 10))
          SignalTP = Price + DefaultTP;
          
          OrderSend(Symbol(), OP_BUY, OrderSize, Price, 3, SignalSL, SignalTP, "Start Trading", MagicNumber, 0, clrNONE);
      }
      if (StringCompare("DAX Short", signal[0]) == 0) {
        double Price = Bid;
        if ( (Price + MaxSlippage < SignalPrice) || (Price - MaxSlippage > SignalPrice) ) {
          Print("Ignoring signal, current price ", Price, " has moved too far away from Signal price", SignalPrice);
          return;
        }

        // assign sane defaults if delivered SL/TP are not plausible        
        if (SignalSL > Price + (DefaultSL + 10))
          SignalSL = Price + DefaultSL;
          
        if (SignalTP < Price - (DefaultTP + 10))
          SignalTP = Price - DefaultTP;
          
          OrderSend(Symbol(), OP_SELL, OrderSize, Price, 3, SignalSL, SignalTP, "Start Trading", MagicNumber, 0, clrNONE);
      }
  }
   
  }   
}
//+------------------------------------------------------------------+
