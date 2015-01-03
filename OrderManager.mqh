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
extern bool onlyCurrentSymbol   = false;

enum Abs_Proz 
  {
   Pips=0,     // Pips
   Prozent=1,  // Prozent
  };

// initialer Abstand des TP/SL zum Einstiegskurs
extern double TP_Pips           = 40;
extern double TP_Percent        = 0.4;
input Abs_Proz TP_Grenze        = Prozent; 
extern double SL_Pips           = 30;
extern double SL_Percent        = 0.3;
input Abs_Proz SL_Grenze        = Prozent;

// Nachziehen des TP
// Auf 0 setzen damit kein Nachziehen des TP erfolgt
extern double TP_Trail_Pips     = 15;
extern double TP_Trail_Percent  = 0.15;
input Abs_Proz TP_Trail_Grenze  = Prozent; 
// Nachziehen des SL
//extern double SLTrailPips       = 15;
//extern double SLTrailPercent    = 0.15;
//input Abs_Proz SLTrail_Grenze   = Prozent; 

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
  return(0);
}

//+------------------------------------------------------------------+
//| expert manageOrders function                                            |
//+------------------------------------------------------------------+
int manageOrders(int myMagicNumber) {

  int rc, Retry, Ticket;
  double Anpassung, TPPips, SLPips, TPTrailPips, TP, SL;

  // Bearbeitung aller offenen Trades
  if (DebugLevel > 2) Print(OrderSymbol()," Orderbuch auslesen (Total alle Symbole: ",OrdersTotal(),")");
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
  
    TP = bestimmeTP(Anpassung, TPPips, TPTrailPips);
    SL = bestimmeSL(TP, SLPips);
  
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
 
  return(newPips);
}


//+------------------------------------------------------------------+
//| TP bestimmen                                                     |
//+------------------------------------------------------------------+
double bestimmeTP(double Anpassung, double TPPips, double TPTrailPips) {
  int OrderDigits = SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS);
  double TakeProfit = OrderTakeProfit();
  MqlTick tick;

  if (SymbolInfoTick(OrderSymbol(), tick)) {
    if (OrderType() == OP_BUY) {
      TakeProfit = fmax(fmax(TakeProfit, OrderOpenPrice()+TPPips), tick.ask+Anpassung*TPTrailPips);
    } else {
      TakeProfit = fmin(fmax(TakeProfit, OrderOpenPrice()-TPPips), tick.bid-Anpassung*TPTrailPips);
    }

    if (TakeProfit != OrderTakeProfit()) {
      double roundhelper = 2*pow(10, OrderDigits-1);
      TakeProfit = NormalizeDouble(round(roundhelper*TakeProfit)/roundhelper, OrderDigits-1);
      if ((DebugLevel > 0) && (TakeProfit != OrderTakeProfit())) {
        string typ;
        if (OrderType() == OP_BUY) {
          typ = "long";
        } else {
          typ = "short";
        }
        Print(OrderSymbol()," TakeProfit neu festgesetzt fuer ", typ, " Order: Kaufpreis: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " alt TakeProfit: ", OrderTakeProfit(), " neu TakeProfit: ", TakeProfit);
      }
    }
  }

  return(TakeProfit);
}


//+------------------------------------------------------------------+
//| SL bestimmen                                                     |
//+------------------------------------------------------------------+
double bestimmeSL(double TakeProfit, double SLPips) {
  double StopLoss = OrderStopLoss();
  int OrderDigits = SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS);
  MqlTick tick;

  if (SymbolInfoTick(OrderSymbol(), tick)) {
    if (OrderType() == OP_BUY) {
      StopLoss = tick.bid - fmin(SLPips, fmin(TakeProfit-tick.bid, tick.bid-StopLoss));
    } else {
      StopLoss = tick.ask + fmin(SLPips, fmin(tick.ask-TakeProfit, fabs(StopLoss-tick.ask))); // fabs, falls StopLoss nicht gesetzt ist (0)
    }

    if (StopLoss != OrderStopLoss()) {
      double roundhelper = 2*pow(10, OrderDigits-1);
      StopLoss = NormalizeDouble(round(roundhelper*StopLoss)/roundhelper, OrderDigits-1);
      if ((DebugLevel > 0) && (StopLoss != OrderStopLoss())) {
        string typ;
        if (OrderType() == OP_BUY) {
          typ = "long";
        } else {
          typ = "short";
        }
        Print(OrderSymbol()," StopLoss neu festgesetzt fuer ", typ, " Order: Kaufpreis: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " alt StopLoss: ", OrderStopLoss(), " neu StopLoss: ", StopLoss);
      }
    }
  }

  return(StopLoss);
}
