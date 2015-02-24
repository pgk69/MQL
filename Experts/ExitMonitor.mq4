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
extern int Debug             = 2;  // Debug Level
// Level 0: Keine Debugausgaben
// Level 1: Nur Orderaenderungen werden protokolliert
// Level 2: Alle Aenderungen werden protokolliert
// Level 3: Alle Programmschritte werden protokolliert
// Level 4: Programmschritte und Datenstrukturen werden im Detail 
//          protokolliert

input int MagicNumber        = 0;

//- onlyCurrentSymbol: true:  Only the current Symbol will be monitored
//                     false: every Symbol will be monitored
input bool onlyCurrentSymbol = true;

input Abs_Proz Percent       = Pips;  // Values given in Pips or Percent

// determine initial TP  30 Pipa = 0.3 Percent
// Pips: 30
// Percent: 0.3
input double TP_Val          = 30;    // Initial TP Value

// determine trailing TP
input double TP_Trail_Val    = 5;     // Trailing TP Value

// determine initial SL
input double SL_Val          = 30;    // Initial SL Value

// determine trailing SL
input bool SL_Trail_activ    = true;  // Activate Trailing SL?
input double SL_Trail_Val    = 5;     // Trailing SL Value

// determine N_Bar SL
input bool SL_N_Bar_activ    = false; // Activate N-Bar SL?
input int BarCount           = 3;     // N-Bar SL: Number of Bars
input int TimeFrame          = -1;    // N-Bar SL: TimeFrame (Autodetect: -1)
input double TimeFrameFaktor = 1.5;   // N-Bar SL: Adatption Timefaktor

// determine Steps SL
input bool SL_Steps_activ    = false;  // Activate Steps SL?
input double SL_Steps_Size   = 15;    // Steps SL: Size of one Step
input double SL_Steps_Val    = 5;     // Steps SL: Triggerdistance above one Stepborder

input bool FollowUp_activ    = false; // Activate FollowUp Trade?
extern int FollowUpExpiry    = 1800;  // FollowUp Order Expiry Time

input int MaxRetry           = 10;   // OrderSend/OrderModify max. Retry
input int PipCorrection      = 1;    // Correction faktor for calculation Pips from Price

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
  pipCorrection(PipCorrection);
  ExitStrategies_Init();
  if (FollowUpExpiry < 600) debug(1, "FollowUpExpiry must be >= 600");
  FollowUpExpiry = fmax(600, FollowUpExpiry);
  ExitStrategieStatus("Trailing",      SL_Trail_activ);
  ExitStrategieStatus("N-Bar",         SL_N_Bar_activ);
  ExitStrategieStatus("Steps",         SL_Steps_activ);
  ExitStrategieStatus("FollowUpOrder", FollowUp_activ);
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
  debug(4, "Read Orderbook (Total of all Symbols: " + i2s(OrdersTotal()) + ")");
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
    double TPPips = calcPips(Percent, TP_Val);
    double SLPips = calcPips(Percent, SL_Val);
    double TPTrailPips = calcPips(Percent, TP_Trail_Val);
    double SLTrailPips = calcPips(Percent, SL_Trail_Val);
    double SLStepsPips = calcPips(Percent, SL_Steps_Size);
    double SLStepsDist = calcPips(Percent, SL_Steps_Val);
  
    // Caluculate new TP Value
    string TPMessage = "";
    double TP = TakeProfit(TPMessage, myOrderTakeProfit, TPPips, TPTrailPips, Correction);

    // Calculate new SL Value
    string SLMessage = "";
    double SL = StopLoss(SLMessage, myOrderStopLoss, TPPips, SLPips, SLTrailPips, Correction, TimeFrame, BarCount, TimeFrameFaktor, SLStepsPips, SLStepsDist);
   
    if (SL != myOrderStopLoss || TP != myOrderTakeProfit) {
      if (debugLevel() >= 1) {
        string message = "";
        if (TP != myOrderTakeProfit) message = message + " new " + TPMessage + "TP:" + d2s(myOrderTakeProfit) + "->" + d2s(TP) + " ";
        if (SL != myOrderStopLoss)   message = message + " new " + SLMessage + "SL:" + d2s(myOrderStopLoss) + "->" + d2s(SL);
        // if (SL != myOrderStopLoss)   message = message + " (Trail:" + tSL + " N-Bar:" + bSL + "/" + BarCount + ")";
        if (Correction != 1)         message = message + " Corrections determined as: " + d2s(Correction);
        debug(1, message);
        if (debugLevel() >= 2) {
          if (TP_Val        != TPPips)      debug(2, "TP Pips changed from "                  + d2s(TP_Val)        + " to " + d2s(TPPips));
          if (TP_Trail_Val  != TPTrailPips) debug(2, "TP trailing Pips changed from "         + d2s(TP_Trail_Val)  + " to " + d2s(TPTrailPips));
          if (SL_Val        != SLPips)      debug(2, "SL Pips changed from "                  + d2s(SL_Val)        + " to " + d2s(SLPips));
          if (SL_Trail_Val  != SLTrailPips) debug(2, "SL trailing Pips changed from "         + d2s(SL_Trail_Val)  + " to " + d2s(SLTrailPips));
          if (SL_Steps_Size != SLStepsPips) debug(2, "SL Steps Size (Pips) changed from "     + d2s(SL_Steps_Size) + " to " + d2s(SLStepsPips));
          if (SL_Steps_Val  != SLStepsDist) debug(2, "SL Steps Distance (Pips) changed from " + d2s(SL_Steps_Val)  + " to " + d2s(SLStepsDist));
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
            executedOrder = "OrderClose (" + i2s(myTicket) + ") rc: " + i2s(rc);
          } else {
            rc = OrderModify(myTicket, 0, SL, TP, 0, CLR_NONE);
            executedOrder = "OrderModify (" + i2s(myTicket) + ", 0, " + d2s(SL) + ", " + d2s(TP) + ", 0, CLR_NONE) TP/SL set: " + i2s(rc);
            if (myOrderStopLoss != 0) rcint = followUpOrder(myTicket, FollowUpExpiry);
          }
        }
        if (OrderType() == OP_SELL) {
          if (tick.ask > SL) {
            rc = OrderClose(myTicket, myOrderLots, tick.ask, 3, clrNONE);
            executedOrder = "OrderClose (" + i2s(myTicket) + ") rc: " + i2s(rc);
          } else {
            rc = OrderModify(myTicket, 0, SL, TP, 0, CLR_NONE);
            executedOrder = "OrderModify (" + i2s(myTicket) + ", 0, " + d2s(SL) + ", " + d2s(TP) + ", 0, CLR_NONE) TP/SL set: " + i2s(rc);
            if (myOrderStopLoss != 0) rcint = followUpOrder(myTicket, FollowUpExpiry);
          }
        }
        Retry++;
      }
      if (!rc) {
        rcint = GetLastError();
        debug(1, executedOrder + " " + i2s(rc) + " " + i2s(rcint) + " " + i2s(Retry) + ": " + ErrorDescription(rcint));
      } else {
        debug(3, executedOrder + "  Retry: " + i2s(Retry));
      }
    }
  }
}