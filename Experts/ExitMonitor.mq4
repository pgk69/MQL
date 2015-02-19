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
extern int FollowUpExpiry       = 1800;

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
  if (FollowUpExpiry < 600) debug(1, "FollowUpExpiry must be >= 600");
  FollowUpExpiry = fmax(600, FollowUpExpiry);
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
  int rcint, Retry;
  bool rc;

  // Bearbeitung aller offenen Trades
  debug(4, StringConcatenate("Read Orderbook (Total of all Symbols: ",OrdersTotal(),")"));
  for (int i=0; i<OrdersTotal(); i++) {
    if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false) continue; // Only valid Tickets are processed
    if ((OrderType() > OP_SELL))                             continue; // Only OP_BUY or OP_SELL Tickets are processed
    if (onlyCurrentSymbol && (OrderSymbol() != Symbol()))    continue; // according to onlyCurrentSymbol only tickets trading the current symbol are processed
    if (MagicNumber && (OrderMagicNumber() != MagicNumber))  continue; // according to MagicNumber only tickets with fitting magicnumber are processed
    
    // Save my Values
    int    myTicket          = OrderTicket();
    int    myOrderType       = OrderType();
    string myOrderSymbol     = OrderSymbol();
    double myOrderOpenPrice  = OrderOpenPrice();
    double myOrderTakeProfit = OrderTakeProfit();
    double myOrderStopLoss   = OrderStopLoss();
    double myOrderLots       = OrderLots();
    
    // Possibly determine an correctionfactor
    double Correction = indFaktor();
    // Calculate real Pips depending on the value given in precent or absolut
    double TPPips = calcPips(TP_Grenze, TP_Percent, TP_Pips);
    double SLPips = calcPips(SL_Grenze, SL_Percent, SL_Pips);
    double TPTrailPips = calcPips(TP_Trail_Grenze, TP_Trail_Percent, TP_Trail_Pips);
    double SLTrailPips = calcPips(SL_Trail_Grenze, SL_Trail_Percent, SL_Trail_Pips);
  
    // Caluculate new TP Value
    double TP = TP(myOrderTakeProfit, TPPips, TPTrailPips, Correction);

    // Calculate new SL Value
    double SL = SL(myOrderStopLoss, TPPips, SLPips, SLTrailPips, Correction, -1, BarCount, TimeFrameFaktor, myTicket, FollowUpExpiry);
   
    if (SL != myOrderStopLoss || TP != myOrderTakeProfit) {
      if (debugLevel() >= 1) {
        string message = "";
        if (TP != myOrderTakeProfit) message = StringConcatenate(message, " TP:", myOrderTakeProfit, "->", TP, " ");
        if (SL != myOrderStopLoss)   message = StringConcatenate(message, " SL:", myOrderStopLoss, "->", SL);
        // if (SL != myOrderStopLoss)   message = StringConcatenate(message, " (Trail:", tSL, " N-Bar:", bSL, "/", BarCount, ")");
        if (Correction != 1)         message = StringConcatenate(message, " Corrections determined as: ", Correction);
        debug(1, StringConcatenate("new TP/SL: ", message));
        if (debugLevel() >= 2) {
          if (TP_Pips != TPPips)            debug(1, StringConcatenate("TP_Pips changed from ", TP_Pips, " to ", TPPips));
          if (TP_Trail_Pips != TPTrailPips) debug(1, StringConcatenate("TP_Trail_Pips changed from ", TP_Trail_Pips, " to ", TPTrailPips));
          if (SL_Pips != SLPips)            debug(1, StringConcatenate("SL_Pips changed from ", SL_Pips, " to ", SLPips));
        }
      }
      Retry  = 0;
      rc     = false;
      rcint  = 0;
      string executedOrder;
      while (!rc && (Retry<MaxRetry)) {
        RefreshRates();
        MqlTick tick;
        SymbolInfoTick(myOrderSymbol, tick);
        if (OrderType() == OP_BUY) {
          if (tick.bid < SL) {
            rc = OrderClose(myTicket, myOrderLots, tick.bid, 3, clrNONE);
            executedOrder = StringConcatenate("OrderClose (", myTicket, ") rc: ", rc);
          } else {
            rc = OrderModify(myTicket, 0, SL, TP, 0, CLR_NONE);
            executedOrder = StringConcatenate("OrderModify (", myTicket, ", 0, ", SL, ", ", TP, ", 0, CLR_NONE) TP/SL set: ", rc);
            if (myOrderStopLoss != 0) rcint = followUpOrder(myTicket, FollowUpExpiry);
          }
        }
        if (OrderType() == OP_SELL) {
          if (tick.ask > SL) {
            rc = OrderClose(myTicket, myOrderLots, tick.ask, 3, clrNONE);
            executedOrder = StringConcatenate("OrderClose (", myTicket, ") rc: ", rc);
          } else {
            rc = OrderModify(myTicket, 0, SL, TP, 0, CLR_NONE);
            executedOrder = StringConcatenate("OrderModify (", myTicket, ", 0, ", SL, ", ", TP, ", 0, CLR_NONE) TP/SL set: ", rc);
            if (myOrderStopLoss != 0) rcint = followUpOrder(myTicket, FollowUpExpiry);
          }
        }
        Retry++;
      }
      if (!rc) {
        rcint = GetLastError();
        debug(1, StringConcatenate(executedOrder, " ", rc, " ", rcint, " ", Retry, ": ", ErrorDescription(rcint)));
      } else {
        debug(3, StringConcatenate(executedOrder, "  Retry: ", Retry));
      }
    }
  }
}