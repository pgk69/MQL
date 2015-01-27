//+------------------------------------------------------------------+
//|                                                 OrderManager.mqh |
//|                                      Copyright 2014, Peter Kempf |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Peter Kempf"
#property link      "http://www.mql4.com"
#property strict

#define VERSION     "1.0"

#include <stderror.mqh>
#include <stdlib.mqh>

//--- input parameters
extern bool onlyCurrentSymbol   = true;

enum Abs_Proz 
  {
   Pips=0,     // Pips
   Prozent=1,  // Prozent
  };

// initialer Abstand des TP/SL zum Einstiegskurs
extern double TP_Pips           = 30;
extern double TP_Percent        = 0.3;
input Abs_Proz TP_Grenze        = Pips; 
extern double SL_Pips           = 30;
extern double SL_Percent        = 0.3;
input Abs_Proz SL_Grenze        = Pips;

// Nachziehen des TP
// Auf 0 setzen damit kein Nachziehen des TP erfolgt
extern double TP_Trail_Pips     = 10;
extern double TP_Trail_Percent  = 0.10;
input Abs_Proz TP_Trail_Grenze  = Pips;
extern double SL_Trail_Pips     = 5;
extern double SL_Trail_Percent  = 0.05;
input Abs_Proz SL_Trail_Grenze  = Pips;

extern int MaxRetry             = 10;

extern int DebugLevel           = 2;
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderaenderungen werden protokolliert
// Level 2: Alle Aenderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert

//--- Global variables
bool newTPset;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
void OrderManager_Init() {
  Print("OrderManager Version: ", VERSION);
  //double A = SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_CONTRACT_SIZE);
  //double A1 = log10(A);
  //double A2 = A1+0.5;
  //double A3 = round(A2);
  //double B = 2-round(log10(A)+0.5);
  //double C = pow(10, B);
  //double PipFaktor = pow(10, 2-round(log10(SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_CONTRACT_SIZE))+0.5));
  //double D = PipFaktor*30;
  //Print("Trade Contract Size=",SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_CONTRACT_SIZE)); 
  //Print("SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_CONTRACT_SIZE)  A:", A); 
  //Print("log10(A):", A1); 
  //Print("log10(A)+0.5:", A2); 
  //Print("round(log10(A)+0.5):", A3); 
  //Print("round(log10(A)+0.5) - 2  B:", B); 
  //Print("pow(10, B)  C:", C); 
  //Print("PipFaktor (pow(10, 2-round(log10(SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_CONTRACT_SIZE))+0.5))): ", PipFaktor); 
  //Print("PipFaktor*30: ", D);
}

//+------------------------------------------------------------------+
//| expert manageOrders function                                            |
//+------------------------------------------------------------------+
int manageOrders(int myMagicNumber) {

  int rc, Retry, Ticket;
  double Anpassung, TPPips, SLPips, TPTrailPips, TP, SL, SLTrailPips;

  // Bearbeitung aller offenen Trades
  if (DebugLevel > 3) Print(OrderSymbol()," Orderbuch auslesen (Total alle Symbole: ",OrdersTotal(),")");
  for (int i=0; i<OrdersTotal(); i++) {
    // Nur gueltige Trades verarbeiten
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)    continue;
    // Nur OP_BUY oder OP_SELL Trades verarbeiten
    if ((OrderType() != OP_BUY) && (OrderType() != OP_SELL))    continue;
    // in Abhaengigkeit von onlyCurrentSymbol wird nur das aktuelle Symbol oder alle Symbole ausgewertet
    if (onlyCurrentSymbol && (OrderSymbol() != Symbol()))       continue;
    // in Abhaengigkeit von MagicNumber werden nur Symbol mit uebereinstimmender MagicNumber verarbetet
    if (myMagicNumber && (OrderMagicNumber() != myMagicNumber)) continue;
 
    // Durch Indikator ermittelter Anpassungsfaktor bestimmen
    Anpassung = indFaktor();
    // Falls TPPercent angegeben ist, wird TPPips errechnet
    TPPips = calcPips(TP_Grenze, TP_Percent, TP_Pips);
    // Falls SLPercent angegeben ist, wird SLPips errechnet
    SLPips = calcPips(SL_Grenze, SL_Percent, SL_Pips);
    // Falls TPTrailPercent angegeben ist, wird TPTrailPips errechnet
    TPTrailPips = calcPips(TP_Trail_Grenze, TP_Trail_Percent, TP_Trail_Pips);
    // Falls TPTrailPercent angegeben ist, wird TPTrailPips errechnet
    SLTrailPips = calcPips(SL_Trail_Grenze, SL_Trail_Percent, SL_Trail_Pips);
  
    TP = bestimmeTP(Anpassung, OrderTakeProfit(), TPPips, TPTrailPips, OrderStopLoss(), SLPips, SLTrailPips);
    SL = bestimmeSL(Anpassung, OrderTakeProfit(), TPPips, TPTrailPips, OrderStopLoss(), SLPips, SLTrailPips);
  
    if (SL != OrderStopLoss() || TP != OrderTakeProfit()) {
      if (DebugLevel > 1) {
        Print(OrderSymbol(), " OrderModify(SL:", SL, ", TP:", TP, ")");
        Print(OrderSymbol()," Anpassungsfaktor bestimmt zu: ", Anpassung);
        if (TP_Pips != TPPips)            Print(OrderSymbol(), " TP_Pips geaendert von ", TP_Pips, " nach ", TPPips);
        if (TP_Trail_Pips != TPTrailPips) Print(OrderSymbol(), " TP_Trail_Pips geaendert von ", TP_Trail_Pips, " nach ", TPTrailPips);
        if (SL_Pips != SLPips)            Print(OrderSymbol(), " SL_Pips geaendert von ", SL_Pips, " nach ", SLPips);
      }
      Retry  = 0;
      rc     = 0;
      Ticket = OrderTicket();
      while ((rc == 0) && (Retry < MaxRetry)) {
        RefreshRates();
        rc = OrderModify(Ticket, 0, SL, TP, 0, CLR_NONE);
        if (!rc) {
          rc = GetLastError();
          if (DebugLevel > 0) Print(OrderSymbol(), " OrderModify(", Ticket, ", 0, ", SL, ", ", TP, ", 0, CLR_NONE) TP/SL set: ", rc);
          Print(IntegerToString(rc) + ": " + ErrorDescription(rc));
        } else {
          if (DebugLevel > 1) Print(OrderSymbol(), " OrderModify(", Ticket, ", 0, ", SL, ", ", TP, ", 0, CLR_NONE) TP/SL set: ", rc);
        }
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
  // double Mom12, Mom20;
  // Mom12 = iMomentum(NULL, 0, 12, PRICE_CLOSE, 0);
  // Mom20 = iMomentum(NULL, 0, 20, PRICE_CLOSE, 0);
  // Print(OrderSymbol()," Momentum 12: ", Mom12, "  Momentum 20: ", Mom20);
  return(1);
}


//+------------------------------------------------------------------+
//| ggf. Prozentumrechnung und Umrechnung OrderPoints                |
//+------------------------------------------------------------------+
double calcPips(double Grenze, double Prozent, double Pips) {
  double newPips;
  MqlTick tick;
  
  if(Grenze && Prozent && SymbolInfoTick(OrderSymbol(), tick)) {
    if (OrderType() == OP_BUY) {
      newPips = Prozent/100 * tick.ask;
    } else {
      newPips = Prozent/100 * tick.bid;
    }
  } else {
    newPips = 10*SymbolInfoDouble(OrderSymbol(), SYMBOL_POINT)*Pips;
  }
  // Print("Old: " + Pips + "  Neu: " + newPips + "  Point: " + SymbolInfoDouble(OrderSymbol(), SYMBOL_POINT) + "  Digits: " + SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS) + "  Ticksize: " + SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_TICK_SIZE));
 
  return(newPips);
}


//+------------------------------------------------------------------+
//| ggf. Normalize and Round                                         |
//+------------------------------------------------------------------+
double NormRound(double Value) {
  int    OrderDigits        = SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS);
  double OrderTradeTickSize = SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_TICK_SIZE);

  if (DebugLevel > 2) Print("Normalizing ", Value, " OrderTradeTickSize * round(Value/OrderTradeTickSize): ", OrderTradeTickSize * round(Value/OrderTradeTickSize), "  NormalizeDouble(Value, OrderDigits): ", NormalizeDouble(Value, OrderDigits));
  Value = OrderTradeTickSize * round(Value/OrderTradeTickSize);
  Value = NormalizeDouble(Value, OrderDigits);

  return(Value);
}


//+------------------------------------------------------------------+
//| TP bestimmen                                                     |
//+------------------------------------------------------------------+
double bestimmeTP(double Anpassung, double myTP, double TPPips, double TPTrailPips, double mySL, double SLPips, double SLTrailPips) {
  MqlTick tick;
  double newTP = myTP;
  double newTPTrail;

  newTPset = false;
  if (SymbolInfoTick(OrderSymbol(), tick)) {
    if (OrderType() == OP_BUY) {
      if (myTP == 0) {                                                         // Initialisierung
        newTP = NormRound(tick.bid + TPPips);
      } else {
        newTPTrail = NormRound(tick.bid + Anpassung*TPTrailPips);
        newTP      = fmax(myTP, newTPTrail);
      }
    } else {
      if (myTP == 0) {                                                         // Initialisierung
        newTP = NormRound(tick.ask - TPPips);
      } else {
        newTPTrail = NormRound(tick.ask - Anpassung*TPTrailPips);
        newTP      = fmin(myTP, newTPTrail);
      }
    }
    
    if (newTP != myTP) {
      if (DebugLevel > 0) {
        if (myTP == 0) {
          Print(OrderSymbol()," initialer TakeProfit ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Kaufpreis: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " initial: ", newTP);
        } else {
          Print(OrderSymbol()," neuer TakeProfit ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Kaufpreis: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " alt: ", myTP, " neu: ", newTP);
        }
      }
      if (myTP != 0) newTPset = true;
      myTP = newTP;
    }
  }

  return(myTP);
}

// Wenn ich Long  kaufen    kriege ich den ask Kurs
// Wenn ich Long  verkaufen kriege ich den bid Kurs
// Wenn ich Short kaufen    kriege ich den bid Kurs
// Wenn ich Short verkaufen kriege ich den ask Kurs

//+------------------------------------------------------------------+
//| SL bestimmen                                                     |
//+------------------------------------------------------------------+
double bestimmeSL(double Anpassung, double myTP, double TPPips, double TPTrailPips, double mySL, double SLPips, double SLTrailPips) {
  MqlTick tick;
  double newSL = mySL;

  if (SymbolInfoTick(OrderSymbol(), tick)) {
    if (OrderType() == OP_BUY) {
      if (mySL == 0) {                                                         // Initialisierung
        newSL = NormRound(tick.bid - SLPips);
      } else {
        if (newTPset || (myTP < tick.bid + Anpassung*TPTrailPips)) {           // Trailing SL falls TP erhoeht wird; SL wird nie verringert
          newSL = fmax(mySL, NormRound(tick.bid - SLTrailPips));
        }
      }
    } else {
      if (mySL == 0) {                                                         // Initialisierung
        newSL = NormRound(tick.ask + SLPips);
      } else {
        if (newTPset || (myTP > tick.ask - Anpassung*TPTrailPips)) {           // Trailing SL falls TP verringert wird; SL wird nie erhoeht
          newSL = fmin(mySL, NormRound(tick.ask + SLTrailPips));
        }
      }
    }
    if (newSL != mySL) {
      if (DebugLevel > 0) {
        if (myTP == 0) {
          Print(OrderSymbol()," initialer StopLoss ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Kaufpreis: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " initial: ", newSL);
        } else {
          Print(OrderSymbol()," neuer StopLoss ", OrderType() ? "short" : "long", " Order (", OrderTicket(), "): Kaufpreis: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " alt: ", mySL, " neu: ", newSL);
        }
      }
      mySL = newSL;
    }
  }

  return(mySL);
}
