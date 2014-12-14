//+------------------------------------------------------------------+
//|                                                 Ordermonitor.mq4 |
//|                                                      Peter Kempf |
//|                                                      Version 1.0 |
//+------------------------------------------------------------------+
#property copyright "Peter Kempf"
#property link      ""

#define VERSION     "1.0"

//--- input parameters
extern double TrailingLimitPips = 150;
extern int MagicNumber          = 11041963;
extern int MaxRetry             = 10;
extern bool onlyCurrentSymbol   = true;
extern int DebugLevel           = 1;
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderaenderungen werden protokolliert
// Level 2: Alle Aenderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert

//--- Global variables


// Imports
#import "kernel32.dll"
int  FindFirstFileA(string path,int &answer[]);
bool FindNextFileA(int handle,int &answer[]);
bool FindClose(int handle);
#import


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
  Print("Version: ",VERSION);
  TrailingLimitPips=TrailingLimitPips/pow(10, Digits);
  Print("TrailingLimitPips: ",TrailingLimitPips);
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

  int i, rc, Retry, Ticket;
  double SL, TP;

  // Durch Indikator ermittelter Anpassungsfaktor bestimmen
  double Anpassung = indFaktor();
  if (DebugLevel > 2) Print(Symbol()," Anpassungsfaktor bestimmt zu: ", Anpassung);
  
  // Bearbeitung aller offenen Trades
  if (DebugLevel > 2) Print(Symbol()," Orderbuch auslesen (Total alle Symbole: ",OrdersTotal(),")");
  for (i=0; i<OrdersTotal(); i++) {
    // in Abhaengigkeit von onlyCurrentSymbol wird nur das aktuelle Symbol oder alle Symbole ausgewertet
    if ((OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) || 
       (onlyCurrentSymbol && (OrderSymbol() != Symbol())) || 
       ((OrderType() != OP_BUY) && (OrderType() != OP_SELL))) continue;
  
    TP = bestimmeTP(Anpassung);
    SL = bestimmeSL(TP);
  
    if (SL != OrderStopLoss() || TP != OrderTakeProfit()) {
      Retry  = 0;
      rc     = 0;
      Ticket = OrderTicket();
      while ((rc == 0) && (Retry < MaxRetry)) {
        RefreshRates();
        rc = OrderModify(Ticket, 0, NormalizeDouble(SL,Digits), NormalizeDouble(TP,Digits), 0, CLR_NONE);
        if (DebugLevel > 0) Print(Symbol(), " OrderModify(", Ticket, ", 0, ", SL, ", ", TP, ", 0, CLR_NONE) TP/SL set: ", rc);
        Retry++;
      }
    }
  }

  return(0);
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Anpassungsfaktor bestimmen                                       |
//+------------------------------------------------------------------+
double indFaktor() {
  double Mom12, Mom20;
  Mom12 = iMomentum(NULL,0,12,PRICE_CLOSE,0);
  Mom20 = iMomentum(NULL,0,20,PRICE_CLOSE,0);
  // Print(Symbol()," Momentum 12: ", Mom12, "  Momentum 20: ", Mom20);
  return(1);
}


//+------------------------------------------------------------------+
//| TP bestimmen                                                     |
//+------------------------------------------------------------------+
double bestimmeTP(double Anpassung) {
  double TP, TL, Price, Delta;
  
  TP = OrderTakeProfit();
  if (OrderType() == OP_BUY) {
    TL    = TrailingLimitPips;
    Price = Ask;
  } else {
    TL    = -TrailingLimitPips;
    Price = Bid;
  }
  
  if (TP == 0) {
    // Falls TP nicht gesetzt ist auf Default setzen
    TP = Price + 2*TL;
  } else {
    // Falls der aktuelle Marktpreis sich unter den mit 'Anpassung' 
    // gewichteten Abstand zum TP bewegt, wird TP angehoben
    Delta = fabs(TP-Price);
    if (Delta < fabs(Anpassung*TL)) {
      TP = Price + Anpassung*TL;
    }
  }
  if (DebugLevel > 1) {
    if (TP != OrderTakeProfit()) {
      string typ;
      if (OrderType() == OP_BUY) {
        typ = "long";
      } else {
        typ = "short";
      }
      Print(Symbol()," TP neu festgesetzt für ", typ, " Order: Kaufpreis: ", NormalizeDouble(OrderOpenPrice(), Digits), " Preis: ", Price, " alt TP: ", NormalizeDouble(OrderTakeProfit(), Digits), " neu TP: ", NormalizeDouble(TP, Digits));
    }
  }

  return(TP);
}


//+------------------------------------------------------------------+
//| SL bestimmen                                                     |
//+------------------------------------------------------------------+
double bestimmeSL(double TP) {
  double SL, TL, Price;
  
  SL = OrderStopLoss();
  if (OrderType() == OP_BUY) {
    TL    = -TrailingLimitPips;
    Price = Bid;
  } else {
    TL    = TrailingLimitPips;
    Price = Ask;
  }
  
  if (SL == 0) {
    // Falls SL nicht gesetzt ist auf Default setzen
    SL = Price + 2*TL;
  } else {
    // SL symmetrisch zum TP setzen, aber nur, wenn es 'besser' wird
    if (OrderType() == OP_BUY) {
      SL = MathMin(SL, Price - (TP-Price));
    } else {
      SL = MathMax(SL, Price - (TP-Price));
    }
  }
  if (DebugLevel > 1) {
    if (SL != OrderStopLoss()) {
      string typ;
      if (OrderType() == OP_BUY) {
        typ = "long";
      } else {
        typ = "short";
      }
      Print(Symbol()," SL neu festgesetzt für ", typ, " Order: Kaufpreis: ", NormalizeDouble(OrderOpenPrice(), Digits), " Preis: ", Price, " alt SL: ", NormalizeDouble(OrderStopLoss(), Digits), " neu SL: ", NormalizeDouble(SL, Digits));
    }
  }

  return(SL);
}
