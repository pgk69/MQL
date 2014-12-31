//+------------------------------------------------------------------+
//|                                                 OrderManager.mqh |
//|                                      Copyright 2014, Peter Kempf |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Peter Kempf"
#property link      "http://www.mql4.com"
#property strict

#define VERSION     "1.0"

//--- input parameters
extern bool onlyCurrentSymbol   = true;

enum Abs_Proz 
  {
   Pips=0,     // Pips
   Prozent=1,  // Prozent
  };

// initialer Abstand des TP/SL zum Einstiegskurs
extern double TPPips            = 30;
extern double TPPercent         = 0.3;
input Abs_Proz TP_Grenze        = Pips; 
extern double SLPips            = 30;
extern double SLPercent         = 0.3;
input Abs_Proz SL_Grenze        = Pips;

// Nachziehen des TP
// Auf 0 setzen damit kein Nachziehen des TP erfolgt
extern double TPTrailPips       = 15;
extern double TPTrailPercent    = 0.15;
input Abs_Proz TPTrail_Grenze   = Pips; 
// Nachziehen des SL
extern double SLTrailPips       = 15;
extern double SLTrailPercent    = 0.15;
input Abs_Proz SLTrail_Grenze   = Pips; 

extern int MaxRetry             = 10;

extern int DebugLevel           = 1;
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderaenderungen werden protokolliert
// Level 2: Alle Aenderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert

//--- Global variables


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OrderManager_Init() {
  Print("OrderManager Version: ", VERSION);
  TPPips      = TPPips/pow(10, Digits-1);
  TPTrailPips = TPTrailPips/pow(10, Digits-1);
  SLPips      = SLPips/pow(10, Digits-1);
  SLTrailPips = SLTrailPips/pow(10, Digits-1);
  Print("TPPips:      ", TPPips);
  Print("SLPips:      ", TPPips);
  Print("TPTrailPips: ", TPTrailPips);
  Print("SLTrailPips: ", TPTrailPips);
  return(0);
}

//+------------------------------------------------------------------+
//| expert manageOrders function                                            |
//+------------------------------------------------------------------+
int manageOrders(string MagicNumber) {

  int i, rc, Retry, Ticket;
  double SL, TP;
  MqlTick last_tick;

  // Durch Indikator ermittelter Anpassungsfaktor bestimmen
  double Anpassung = indFaktor();
  if (DebugLevel > 2) Print(Symbol()," Anpassungsfaktor bestimmt zu: ", Anpassung);
  
  // Bearbeitung aller offenen Trades
  if (DebugLevel > 2) Print(Symbol()," Orderbuch auslesen (Total alle Symbole: ",OrdersTotal(),")");
  for (i=0; i<OrdersTotal(); i++) {
    // Nur gueltige Trades verarbeiten
    if (OrderSelect(i, SELECT_BY_POS,MODE_TRADES) == false)  continue;
    // Nur OP_BUY oder OP_SELL Trades verarbeiten
    if ((OrderType() != OP_BUY) && (OrderType() != OP_SELL)) continue;
    // in Abhaengigkeit von onlyCurrentSymbol wird nur das aktuelle Symbol oder alle Symbole ausgewertet
    if (onlyCurrentSymbol && (OrderSymbol() != Symbol()))    continue;
    // in Abhaengigkeit von MagicNumber werden nur Symbol mit uebereinstimmender MagicNumber verarbetet
    // Wird vom aufrufenden Programm geregelt
    if (MagicNumber && (OrderMagicNumber() != MagicNumber))  continue;
 
    // Falls TPPercent angegeben ist, wird TPPips errechnet
    if(TP_Grenze && TPPercent && SymbolInfoTick(Symbol(),last_tick)) {
      if (OrderType() == OP_BUY) {
        TPPips = TPPercent/100 * last_tick.ask;
      } else {
        TPPips = TPPercent/100 * last_tick.bid;
      }
      if (DebugLevel > 0) Print(Symbol(), " TPPips geaendert nach ", TPPips);
    }
 
    // Falls TPTrailPercent angegeben ist, wird TPTrailPips errechnet
    if(TPTrail_Grenze && TPTrailPercent && SymbolInfoTick(Symbol(),last_tick)) {
      if (OrderType() == OP_BUY) {
        TPTrailPips = TPTrailPercent/100 * last_tick.ask;
      } else {
        TPTrailPips = TPTrailPercent/100 * last_tick.bid;
      }
      if (DebugLevel > 0) Print(Symbol(), " TPTrailPips geaendert nach ", TPTrailPips);
    }
  
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
  Mom12 = iMomentum(NULL, 0, 12, PRICE_CLOSE, 0);
  Mom20 = iMomentum(NULL, 0, 20, PRICE_CLOSE, 0);
  // Print(Symbol()," Momentum 12: ", Mom12, "  Momentum 20: ", Mom20);
  return(1);
}


//+------------------------------------------------------------------+
//| TP bestimmen                                                     |
//+------------------------------------------------------------------+
double bestimmeTP(double Anpassung) {
  double TakeProfit, TP, TTP, Price, Delta;
  
  TakeProfit = OrderTakeProfit();
  if (OrderType() == OP_BUY) {
    TP    = TPPips;
    TTP   = TPTrailPips;
    Price = Ask;
  } else {
    TP    = -TPPips;
    TTP   = -TPTrailPips;
    Price = Bid;
  }
  
  if (TakeProfit == 0) {
    // Falls TakeProfit nicht gesetzt ist auf Default (TP) setzen
    TakeProfit = Price + TP;
  } else {
    // Falls TakeProfit gesetzt ist wird ggf. der TakeProfit nachgezogen: 
    // Falls der aktuelle Marktpreis sich unter den mit 'Anpassung' 
    // gewichteten Abstand zum TakeProfit bewegt, wird TakeProfit angehoben
    Delta = fabs(TakeProfit-Price);
    if (Delta < fabs(Anpassung*TTP)) {
      TakeProfit = Price + Anpassung*TTP;
    }
  }
  if (DebugLevel > 1) {
    if (TakeProfit != OrderTakeProfit()) {
      string typ;
      if (OrderType() == OP_BUY) {
        typ = "long";
      } else {
        typ = "short";
      }
      Print(Symbol()," TakeProfit neu festgesetzt fuer ", typ, " Order: Kaufpreis: ", NormalizeDouble(OrderOpenPrice(), Digits), " Preis: ", Price, " alt TakeProfit: ", NormalizeDouble(OrderTakeProfit(), Digits), " neu TakeProfit: ", NormalizeDouble(TakeProfit, Digits));
    }
  }

  return(TakeProfit);
}


//+------------------------------------------------------------------+
//| SL bestimmen                                                     |
//+------------------------------------------------------------------+
double bestimmeSL(double TakeProfit) {
  double StopLoss, SP, STP, Price;
  
  StopLoss = OrderStopLoss();
  if (OrderType() == OP_BUY) {
    SP    = -SLPips;
    STP   = -SLTrailPips;
    Price = Bid;
  } else {
    SP    = SLPips;
    STP   = SLTrailPips;
    Price = Ask;
  }
  
  if (StopLoss == 0) {
    // Falls StopLoss nicht gesetzt ist auf Default setzen
    StopLoss = Price + SP;
  } else {
    // StopLoss symmetrisch zum TP setzen, aber nur, wenn es 'besser' wird
    if (OrderType() == OP_BUY) {
      StopLoss = MathMin(StopLoss, Price - (TakeProfit-Price));
    } else {
      StopLoss = MathMax(StopLoss, Price - (TakeProfit-Price));
    }
  }
  if (DebugLevel > 1) {
    if (StopLoss != OrderStopLoss()) {
      string typ;
      if (OrderType() == OP_BUY) {
        typ = "long";
      } else {
        typ = "short";
      }
      Print(Symbol()," StopLoss neu festgesetzt fuer ", typ, " Order: Kaufpreis: ", NormalizeDouble(OrderOpenPrice(), Digits), " Preis: ", Price, " alt StopLoss: ", NormalizeDouble(OrderStopLoss(), Digits), " neu StopLoss: ", NormalizeDouble(StopLoss, Digits));
    }
  }

  return(StopLoss);
}
