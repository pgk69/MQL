//+------------------------------------------------------------------+
//|                                                  ExitMonitor.mq4 |
//|                                                      Peter Kempf |
//|                                                      Version 1.0 |
//+------------------------------------------------------------------+
#property copyright "Peter Kempf"
#property link      ""

//--- type definitons
enum Abs_Proz 
  {
   Pips=0,     // Pips
   Percent=1,  // Percent
  };

//--- input parameters
//- MagicNumber:    0: Every trade will be monitored
//               <> 0: Only trades with MagicNumber will be monitored
extern int MagicNumber = 0;

extern int Debug       = 2;
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderaenderungen werden protokolliert
// Level 2: Alle Aenderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert


//- onlyCurrentSymbol: true:  Only the current Symbol will be monitored
//                     false: every Symbol will be monitored
extern bool onlyCurrentSymbol   = true;

// determine initial TP
extern double TP_Pips           = 30;
extern double TP_Percent        = 0.3;
extern Abs_Proz TP_Grenze       = Pips; 

// determine trailing TP
extern double TP_Trail_Pips     = 10;
extern double TP_Trail_Percent  = 0.10;
extern Abs_Proz TP_Trail_Grenze = Pips;

// determine initial SL
extern double SL_Pips           = 30;
extern double SL_Percent        = 0.3;
extern Abs_Proz SL_Grenze       = Pips;

// determine trailing SL
extern double SL_Trail_Pips     = 5;
extern double SL_Trail_Percent  = 0.05;
extern Abs_Proz SL_Trail_Grenze = Pips;

// determine N_Bar SL
extern int BarCount             = 3;
extern double TimeFrameFaktor   = 1.5;

extern int MaxRetry             = 10;

//--- Global variables

//--- Includes
//#include <stderror.mqh>
#include <stdlib.mqh>
#include <ToolBox.mqh>
#include <ExitStrategies.mqh>

//--- Imports


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  debugLevel(Debug);
  ExitStrategies_Init();
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
}

//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
void OnTick() {
  int rc, Retry, Ticket;
  double Correction, TPPips, SLPips, TPTrailPips, TP, SL, SLTrailPips;
  bool initialTP, resetTP, initialSL, resetSL;

  // Bearbeitung aller offenen Trades
  debug(4, StringConcatenate("Read Orderbook (Total of all Symbols: ",OrdersTotal(),")"));
  for (int i=0; i<OrdersTotal(); i++) {
    // Only valid Tickets are processed
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)    continue;
    // Only OP_BUY or OP_SELL Tickets are processed
    if ((OrderType() != OP_BUY) && (OrderType() != OP_SELL))    continue;
    // according to onlyCurrentSymbol only tickets trading the current symbol are processed
    if (onlyCurrentSymbol && (OrderSymbol() != Symbol()))       continue;
    // according to MagicNumber only tickets with fitting magicnumber are processed
    if (MagicNumber && (OrderMagicNumber() != MagicNumber)) continue;
 
    // Possibly determine an correctionfactor
    Correction = indFaktor();
    // Falls TPPercent angegeben ist, wird TPPips errechnet
    TPPips = calcPips(TP_Grenze, TP_Percent, TP_Pips);
    // Falls SLPercent angegeben ist, wird SLPips errechnet
    SLPips = calcPips(SL_Grenze, SL_Percent, SL_Pips);
    // Falls TPTrailPercent angegeben ist, wird TPTrailPips errechnet
    TPTrailPips = calcPips(TP_Trail_Grenze, TP_Trail_Percent, TP_Trail_Pips);
    // Falls TPTrailPercent angegeben ist, wird TPTrailPips errechnet
    SLTrailPips = calcPips(SL_Trail_Grenze, SL_Trail_Percent, SL_Trail_Pips);
  
    TP = trailing_TP(Correction, OrderTakeProfit(), TPPips, TPTrailPips, initialTP, resetTP);
    double tSL = trailing_SL(Correction, OrderStopLoss(),   SLPips, SLTrailPips, initialSL, resetSL, resetTP);
    double bSL = N_Bar_SL(OrderStopLoss(), SLPips, initialSL, resetSL, -1, BarCount, TimeFrameFaktor);
    if (OrderType() == OP_BUY) {
      SL = fmin(tSL, bSL);
    } else {
      SL = fmax(tSL, bSL);
    }
    
    //if (initialTP || initialSL || resetTP || resetSL) {
    if (SL != OrderStopLoss() || TP != OrderTakeProfit()) {
      // Print(initialTP, " ", initialSL, " ", resetTP, " ", resetSL, " ", tSL, " ", bSL, " ", SL);
      if (debugLevel() >= 1) {
        string message = "";
        if (TP != OrderTakeProfit()) message = StringConcatenate(message, " TP:",OrderTakeProfit(), "->", TP, " ");
        if (SL != OrderStopLoss())   message = StringConcatenate(message, " SL:",OrderStopLoss(), "->", SL, " (Trail:", tSL, " N-Bar:", bSL, "/", BarCount, ")");
        if (Correction != 1)         message = StringConcatenate(message, " Corrections determined as: ", Correction);
        Print(OrderSymbol(), message);
        if (debugLevel() >= 2) {
          if (TP_Pips != TPPips)            Print(OrderSymbol(), " TP_Pips changed from ", TP_Pips, " to ", TPPips);
          if (TP_Trail_Pips != TPTrailPips) Print(OrderSymbol(), " TP_Trail_Pips changed from ", TP_Trail_Pips, " to ", TPTrailPips);
          if (SL_Pips != SLPips)            Print(OrderSymbol(), " SL_Pips changed from ", SL_Pips, " to ", SLPips);
        }
      }
      Retry  = 0;
      rc     = 0;
      Ticket = OrderTicket();
      while ((rc == 0) && (Retry < MaxRetry)) {
        RefreshRates();
        string executedOrder;
        MqlTick tick;
        SymbolInfoTick(OrderSymbol(), tick);
        if (OrderType() == OP_BUY) {
          if (tick.bid < SL) {
            rc = OrderClose(Ticket, OrderLots(), tick.bid, 3, clrNONE);
            executedOrder = StringConcatenate("OrderClose(", Ticket, ") rc: ", rc);
          } else {
            rc = OrderModify(Ticket, 0, SL, TP, 0, CLR_NONE);
            executedOrder = StringConcatenate("OrderModify(", Ticket, ", 0, ", SL, ", ", TP, ", 0, CLR_NONE) TP/SL set: ", rc);
          }
        }
        if (OrderType() == OP_SELL) {
          if (tick.ask > SL) {
            rc = OrderClose(Ticket, OrderLots(), tick.ask, 3, clrNONE);
            executedOrder = StringConcatenate("OrderClose(", Ticket, ") rc: ", rc);
          } else {
            rc = OrderModify(Ticket, 0, SL, TP, 0, CLR_NONE);
            executedOrder = StringConcatenate("OrderModify(", Ticket, ", 0, ", SL, ", ", TP, ", 0, CLR_NONE) TP/SL set: ", rc);
          }
        }
        if (!rc) {
          rc = GetLastError();
          debug(1, StringConcatenate(executedOrder, " ", rc));
          Print(IntegerToString(rc) + ": " + ErrorDescription(rc));
        } else {
          debug(2, executedOrder);
        }
        Retry++;
      }
    }
  }
}