//+------------------------------------------------------------------+
//|                                                 Ordermonitor.mq4 |
//|                                                      Peter Kempf |
//|                                                      Version 0.9 |
//+------------------------------------------------------------------+
#property copyright "Peter Kempf"
#property link      ""

#define VERSION     "0.9"

//--- input parameters
extern int TrailingLimit = 15;
extern int MagicNumber = 11041963;

extern int DebugLevel = 1;
// Level 0: Keine Debugausgaben
// Level 1: Nur Order�nderungen werden protokolliert
// Level 2: Alle �nderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert

// Imports
#import "kernel32.dll"
int  FindFirstFileA(string path, int& answer[]);
bool FindNextFileA(int handle, int& answer[]);
bool FindClose(int handle);
#import

// Global variables

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
  Print ("Version: ", VERSION);
  return(0);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
  return(0);
}

//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {

  bool modifyOrder = false;
  int i, faktor, retry, rc, ticket;
  double price, SL, TP;

  if (DebugLevel > 2) Print (Symbol(), RunMode, "Orderbuch auslesen (Total alle Symbole: ", OrdersTotal(), ")");
  for(i=0; i<OrdersTotal(); i++) {
    // Nur das aktuelle Symbol wird ausgewertet und nur aktive SELL- oder BUY-Positionen
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)==false || 
        OrderSymbol()!= Symbol() || 
        OrderMagicNumber()!= MagicNumber || 
        (OrderType()!=OP_BUY && OrderType()!=OP_SELL))
      continue;
  
    if (OrderType()==OP_SELL) {
      faktor = -1
      prize = NormalizeDouble(Bid, Digits);
    } else {
      faktor = 1;
      prize = NormalizeDouble(Ask, Digits);
    }

    TP = OrderTakeProfit();
    if (TP == 0) {
      TP = prize + faktor * 2 * TrailingLimit;
    }
    SL = OrderStopLoss();
    if (SL == 0) {
      SL = prize - faktor * 2 * TrailingLimit;
    }
    if (faktor * (TP - prize) < faktor * (prize - SL)) {
      if (faktor * (TP - prize) < TrailingLimit) {
        SL = prize - faktor * TrailingLimit;
        TP = prize + faktor * TrailingLimit;
      } else {
        SL = prize - (TP - prize);
      }
    }

    if (SL != OrderStopLoss() || TP != OrderTakeProfit()) {
      retry = 0;
      rc = 0;
      ticket = OrderTicket();
      while ((rc == 0) && (retry < 10)) {
        RefreshRates();
        rc = OrderModify(ticket, 0, NormalizeDouble(SL, Digits), NormalizeDouble(TP, Digits), 0, CLR_NONE);
        if (DebugLevel > 0) Print(Symbol(), " OrderModify(", ticket, ", 0, ", SL, ", ", TP, ", 0, CLR_NONE) TP/SL set: ", rc);
        retry++;
      }
    }
  }

  return(0);
}
