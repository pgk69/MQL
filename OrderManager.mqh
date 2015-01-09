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
  double Anpassung, TPPips, SLPips, TPTrailPips, TP, SL, SLTrailPips;

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
 
  return(newPips);
}


//+------------------------------------------------------------------+
//| TP bestimmen                                                     |
//+------------------------------------------------------------------+
double bestimmeTP(double Anpassung, double TP, double TPPips, double TPTrailPips, double SL, double SLPips, double SLTrailPips) {
  double PricechangePerTick = SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_TICK_SIZE);
  MqlTick tick;

  if (SymbolInfoTick(OrderSymbol(), tick)) {
    if (OrderType() == OP_BUY) {
      TP = fmax(fmax(TP, OrderOpenPrice()+TPPips), tick.ask+Anpassung*TPTrailPips);
    } else {
      TP = fmin(fmax(TP, OrderOpenPrice()-TPPips), tick.bid-Anpassung*TPTrailPips);
    }

    if (TP != OrderTakeProfit()) {
      TP = NormalizeDouble(PricechangePerTick * round(TP / PricechangePerTick));
      if ((DebugLevel > 0) && (TP != OrderTakeProfit())) {
        string typ;
        if (OrderType() == OP_BUY) {
          typ = "long";
        } else {
          typ = "short";
        }
        Print(OrderSymbol()," TakeProfit neu festgesetzt fuer ", typ, " Order: Kaufpreis: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " alt TakeProfit: ", OrderTakeProfit(), " neu TakeProfit: ", TP);
      }
    }
  }

  return(TP);
}


//+------------------------------------------------------------------+
//| SL bestimmen                                                     |
//+------------------------------------------------------------------+
double bestimmeSL(double Anpassung, double TP, double TPPips, double TPTrailPips, double SL, double SLPips, double SLTrailPips) {
  double PricechangePerTick = SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_TICK_SIZE);
  MqlTick tick;

  if (SymbolInfoTick(OrderSymbol(), tick)) {
    if (OrderType() == OP_BUY) {
      if (SL == 0) {
        SL = tick.bid - SLPips;                                             // Initialisierung
      } else {
        if (TP-tick.bid < TPTrailPips) SL = fmax(SL, tick.bid-SLTrailPips); // Trailing SL falls TP erhoeht wird; SL wird nie verringert
      }
    } else {
      if (SL == 0) {
        SL = tick.ask + SLPips;                                             // Initialisierung
      } else {
        if (tick.ask-TP < TPTrailPips) SL = fmin(SL, tick.ask+SLTrailPips); // Trailing SL falls TP verringert wird; SL wird nie erhoeht
      }
    }

    if (SL != OrderStopLoss()) {
      SL = NormalizeDouble(PricechangePerTick * round(SL / PricechangePerTick));
      if ((DebugLevel > 0) && (SL != OrderStopLoss())) {
        string typ;
        if (OrderType() == OP_BUY) {
          typ = "long";
        } else {
          typ = "short";
        }
        Print(OrderSymbol()," StopLoss neu festgesetzt fuer ", typ, " Order: Kaufpreis: ", OrderOpenPrice(), " Bid/Ask: ", tick.bid, "/",tick.ask, " alt StopLoss: ", OrderStopLoss(), " neu StopLoss: ", SL);
      }
    }
  }

  return(SL);
}
