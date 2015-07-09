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
input double MaxGoodSlippage = 100; // Max. Slippage zu unseren Gunsten
input double MaxBadSlippage = 3;    // Max. Slippage zu unseren Ungunsten
input double Delta = 1;             // Abschlag auf Einstieg, SL und TP des Signalgebers
input int MaxSignalAge = 600;       // Max. Signalalter
extern int MaxLimitAge = 300;        // Max. Signalalter fuer Limitorder
extern int SignalExpiration = 3600; // Max. Dauer fuer pending Orders
input double DefaultSL = 34;        // SL Default
input double DefaultTP = 32;        // TP Default
// Lotzahl ActivTrades 25,-  Sensus 0,10(10)  ETX 1,-(25/10)
input double OrderSize = 10;        // Lotanzahl
input int MagicNumber = 9999;       // Magic Number
input string url="http://fx.bartosch.name/start-signal.csv"; // Signal URL
// input string url="http://localhost/start-signal.csv"; // Signal URL

extern int Debug = 2;               // Debug Level
input bool test = false;            // Testmode

int TickCount = 0;
datetime LastProcessedSignal = 0;
uchar sep = ';';

#include <ToolBox.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  if (SignalExpiration < 600) debug(1, "SignalExpiration must be >= 600");
  SignalExpiration = fmax(600, SignalExpiration);
  if (MaxLimitAge > MaxSignalAge) debug(1, "MaxLimitAge must be <= MaxSignalAge");
  MaxLimitAge = fmin(MaxSignalAge, MaxLimitAge);
  debugLevel(fmax(3, Debug));
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
  if (TickCount++ % 5 == 0) {
    // Alert("20. Tick");
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
    if (res==-1) {
      // Alert("Error code =",GetLastError());
    } else {
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
      long signalage = TimeCurrent() - signaltimestamp_epoch;
      
      if (signalage > MaxSignalAge) {
        debug(3, "Signal is " + d2s(signalage) + " seconds old - ignoring (MaxSignalAge: <" + i2s(MaxSignalAge) + ">)");
        debugLevel(fmax(2, Debug));
        return;
      }

      // signal has already been processed, ignore
      if (LastProcessedSignal == signaltimestamp_epoch) {
        debug(3, "Signal has already been processed " + t2s(signaltimestamp_epoch));
        debugLevel(fmax(2, Debug));
        return;
      }
   
      // all checks OK, let's mark this signal as processed
      // perform sanity checks
      // process the signal
      LastProcessedSignal = signaltimestamp_epoch;
      
      double SignalPrice    = StrToDouble(signal[1]);
      double SignalSL       = StrToDouble(signal[2]);
      double SignalTP       = StrToDouble(signal[3]);
      double Price;
      int ExecuteType;
      datetime Expiration;

      if (StringCompare("DAX Long", signal[0]) == 0) {
        SignalPrice = SignalPrice - Delta;
        SignalSL    = SignalSL - Delta;
        SignalTP    = SignalTP - Delta;
        Price       = Ask;
        ExecuteType = OP_BUY;
        Expiration  = 0;
        if ((MaxGoodSlippage < fmod(SignalPrice-Price, 100)) || (fmod(Price-SignalPrice, 100) > MaxBadSlippage)) {
          if (signalage > MaxLimitAge) {
            debug(3, "Signal is " + d2s(signalage) + " seconds old - ignoring (MaxLimitAge: <" + i2s(MaxLimitAge) + ">)");
            debugLevel(fmax(2, Debug));
            return;
          }
          ExecuteType = OP_BUYLIMIT;
          Expiration = TimeCurrent() + SignalExpiration;
          string away;
          if (MaxGoodSlippage < fmod(SignalPrice-Price, 100)) {
            away = d2s(MaxGoodSlippage) + "<" + d2s(fmod(SignalPrice-Price, 100));
          } else {
            away = d2s(fmod(Price-SignalPrice, 100)) +  ">" + d2s(MaxBadSlippage);
          }
          debug(2, "Current price " + d2s(Price) + " moved too far from Signal price " + d2s(SignalPrice) + " (" + away + "). Long order set as OP_BUYLIMIT (Expiration: <" + d2s(Expiration) + ">).");
          Price = SignalPrice;
        }

        // assign sane defaults if delivered SL/TP are not plausible
        if (SignalSL < Price - (DefaultSL + 10)) SignalSL = Price - DefaultSL;
        if (SignalTP > Price + (DefaultTP + 10)) SignalTP = Price + DefaultTP;
        int Ticket = 0;
        if (!test) Ticket = OrderSend(Symbol(), ExecuteType, OrderSize, Price, 3, SignalSL, SignalTP, "Start Trading", MagicNumber, Expiration, clrNONE);
        debug(3, "OrderSend(" + Symbol() + ", " + i2s(ExecuteType) + ", " + d2s(OrderSize) + ", " + d2s(Price) + ", 3, " + d2s(SignalSL) + ", " + d2s(SignalTP) + ", Start Trading, " + i2s(MagicNumber) + ", " + t2s(Expiration) + ", " + i2s(clrNONE) + ")");
      }

      if (StringCompare("DAX Short", signal[0]) == 0) {
        SignalPrice = SignalPrice + Delta;
        SignalSL    = SignalSL + Delta;
        SignalTP    = SignalTP + Delta;
        Price = Bid;
        ExecuteType = OP_SELL;
        Expiration = 0;
        if ((MaxBadSlippage < fmod(SignalPrice-Price, 100)) || (fmod(Price-SignalPrice, 100) > MaxGoodSlippage)) {
          if (signalage > MaxLimitAge) {
            debug(3, "Signal is " + d2s(signalage) + " seconds old - ignoring (MaxLimitAge: <" + i2s(MaxLimitAge) + ">)");
            debugLevel(fmax(2, Debug));
            return;
          }
          ExecuteType = OP_SELLLIMIT;
          Expiration = TimeCurrent() + SignalExpiration;
          string away;
          if (MaxBadSlippage < fmod(SignalPrice-Price, 100)) {
            away = d2s(MaxBadSlippage) + "<" + d2s(fmod(SignalPrice-Price, 100));
          } else {
            away = d2s(fmod(Price-SignalPrice, 100)) +  ">" + d2s(MaxGoodSlippage);
          }
          debug(2, "Current price " + d2s(Price) + " moved too far from Signal price " + d2s(SignalPrice) + " (" + away + "). Short order set as OP_SELLLIMIT (Expiration: <" + d2s(Expiration) + ">).");
          Price = SignalPrice;
        }

        // assign sane defaults if delivered SL/TP are not plausible        
        if (SignalSL > Price + (DefaultSL + 10)) SignalSL = Price + DefaultSL;
        if (SignalTP < Price - (DefaultTP + 10)) SignalTP = Price - DefaultTP;
        int Ticket = 0;
        if (!test) Ticket = OrderSend(Symbol(), ExecuteType, OrderSize, Price, 3, SignalSL, SignalTP, "Start Trading", MagicNumber, Expiration, clrNONE);
        debug(3, "OrderSend(" + Symbol() + ", " + i2s(ExecuteType) + ", " + d2s(OrderSize) + ", " + d2s(Price) + ", 3, " + d2s(SignalSL) + ", " + d2s(SignalTP) + ", Start Trading, " + i2s(MagicNumber) + ", " + t2s(Expiration) + ", " + i2s(clrNONE) + ")");
      }
      debugLevel(fmax(3, Debug));
    }
  }   
}
//+------------------------------------------------------------------+
